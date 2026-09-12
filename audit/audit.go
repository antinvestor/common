// Copyright 2023-2026 Ant Investor Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package audit provides a reusable Connect RPC interceptor and HTTP
// middleware that record human actions in the audit service.
//
// The interceptor captures non-idempotent RPCs whose caller is a person and
// sends one entry per call, synchronously, on a client with a short
// construction-time timeout. Failures are logged and counted, never
// propagated: audit availability must not block the producer.
//
// # Basic usage
//
//	interceptor := audit.NewInterceptor("service_profile", auditClient)
//
// # Handler enrichment
//
//	ctx = audit.WithResource(ctx, "organization", org.GetId())
//	ctx = audit.WithStateChange(ctx, "CREATED", "ACTIVE")
//	ctx = audit.WithRelation(ctx, audit.Relation{ParentType: "profile", ParentID: profileID,
//	    ChildType: "contact", ChildID: contactID, Action: audit.RelationAdded})
//	ctx = audit.WithDetail(ctx, "reason", "customer request")
//	ctx = audit.WithIntent(ctx, intentID, payloadHash, authorizationHash, policyHash)
//
// # Operators acting for a person
//
// A service-account caller produces no entry unless the handler names the
// person it acts for:
//
//	ctx = audit.WithOnBehalfOf(ctx, memberProfileID)
package audit

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"connectrpc.com/connect"
	"github.com/pitabwire/frame/v2/security"
	"github.com/pitabwire/util"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/protobuf/types/known/structpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// ─────────────────────────────────────────────────────────────────────────────
// Context enrichment — handlers use these to add audit metadata
// ─────────────────────────────────────────────────────────────────────────────

type contextKey struct{}

// Entry holds all enrichment data accumulated by handlers during an RPC.
type Entry struct {
	// Resource being acted on.
	ResourceType string
	ResourceID   string
	// ResourceVersion after the action (0 when unknown).
	ResourceVersion int64

	// Override the auto-detected action (e.g. "approve" instead of "Save").
	Action string

	// Profile ID of the target user, if the action affects another user.
	TargetProfileID string

	// OnBehalfOf names the person a service-account caller acts for.
	OnBehalfOf string

	// State transition (e.g. CREATED → ACTIVE).
	StateFrom string
	StateTo   string

	// Relationships created or modified during this action.
	Relations []Relation

	// Evidence join keys.
	EntryID           string
	CorrelationID     string
	EventID           string
	IntentID          string
	InstanceID        string
	PayloadHash       string
	AuthorizationHash string
	PolicyHash        string
	DeviceKeyID       string
	// OccurredAt overrides receipt time (outbox replays).
	OccurredAt time.Time

	// Arbitrary key-value details.
	Details map[string]any

	// Automatically captured from request headers.
	IPAddress string
	UserAgent string
}

// Relation represents a link between two entities that was created,
// modified, or removed during the audited action.
type Relation struct {
	ParentType string // e.g. "profile"
	ParentID   string // e.g. "d75qclkpf2t1uum8ij3g"
	ChildType  string // e.g. "contact"
	ChildID    string // e.g. "d7eloa0jbutr739k3qmg"
	Action     string // RelationAdded, RelationRemoved, RelationModified
}

func entryFromContext(ctx context.Context) *Entry {
	val, _ := ctx.Value(contextKey{}).(*Entry)
	return val
}

func ensureEntry(ctx context.Context) (context.Context, *Entry) {
	e := entryFromContext(ctx)
	if e != nil {
		return ctx, e
	}
	e = &Entry{Details: map[string]any{}}
	return context.WithValue(ctx, contextKey{}, e), e
}

// initEntry pre-populates the context with an empty entry so handlers
// can mutate it in place without creating new context values.
func initEntry(ctx context.Context) context.Context {
	if entryFromContext(ctx) != nil {
		return ctx
	}
	return context.WithValue(ctx, contextKey{}, &Entry{Details: map[string]any{}})
}

// WithResource identifies the primary resource being acted on.
func WithResource(ctx context.Context, resourceType, resourceID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.ResourceType = resourceType
	e.ResourceID = resourceID
	return ctx
}

// WithResourceVersion records the resource version after the action.
func WithResourceVersion(ctx context.Context, version int64) context.Context {
	ctx, e := ensureEntry(ctx)
	e.ResourceVersion = version
	return ctx
}

// WithAction overrides the auto-detected action name.
func WithAction(ctx context.Context, action string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.Action = action
	return ctx
}

// WithTarget sets the target profile affected by this action.
func WithTarget(ctx context.Context, targetProfileID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.TargetProfileID = targetProfileID
	return ctx
}

// WithOnBehalfOf names the person a service-account caller acts for. It is
// the only way a machine caller produces an audit entry.
func WithOnBehalfOf(ctx context.Context, profileID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.OnBehalfOf = profileID
	return ctx
}

// WithStateChange records a state transition on the resource.
func WithStateChange(ctx context.Context, fromState, toState string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.StateFrom = fromState
	e.StateTo = toState
	return ctx
}

// WithRelation records a relationship created, modified, or removed.
func WithRelation(ctx context.Context, rel Relation) context.Context {
	ctx, e := ensureEntry(ctx)
	e.Relations = append(e.Relations, rel)
	return ctx
}

// WithDetail adds a single key-value detail. Keys that look like secrets
// (password, token, otp, …) and values that look like phone or card
// numbers are rejected by the audit service; send hashes instead.
func WithDetail(ctx context.Context, key string, value any) context.Context {
	ctx, e := ensureEntry(ctx)
	if e.Details == nil {
		e.Details = map[string]any{}
	}
	e.Details[key] = value
	return ctx
}

// WithEntryID sets the idempotency key (outbox replays reuse it).
func WithEntryID(ctx context.Context, entryID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.EntryID = entryID
	return ctx
}

// WithCorrelation sets the cross-service correlation id.
func WithCorrelation(ctx context.Context, correlationID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.CorrelationID = correlationID
	return ctx
}

// WithEvent links the entry to a domain event.
func WithEvent(ctx context.Context, eventID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.EventID = eventID
	return ctx
}

// WithInstance links the entry to a workflow instance.
func WithInstance(ctx context.Context, instanceID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.InstanceID = instanceID
	return ctx
}

// WithIntent links the entry to a financial intent and its evidence hashes
// (32-byte lowercase hex, or empty).
func WithIntent(ctx context.Context, intentID, payloadHash, authorizationHash, policyHash string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.IntentID = intentID
	e.PayloadHash = payloadHash
	e.AuthorizationHash = authorizationHash
	e.PolicyHash = policyHash
	return ctx
}

// WithDeviceKey records the device key that signed the request.
func WithDeviceKey(ctx context.Context, deviceKeyID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.DeviceKeyID = deviceKeyID
	return ctx
}

// WithOccurredAt overrides the action time (outbox replays).
func WithOccurredAt(ctx context.Context, at time.Time) context.Context {
	ctx, e := ensureEntry(ctx)
	e.OccurredAt = at
	return ctx
}

// ─────────────────────────────────────────────────────────────────────────────
// Interceptor
// ─────────────────────────────────────────────────────────────────────────────

// Config controls which calls are audited.
type Config interface {
	// AuditShouldSkipRPC returns true if the given Connect RPC should NOT
	// be audited. The default skips idempotent RPCs (Get, Search, List).
	AuditShouldSkipRPC(spec connect.Spec) bool

	// AuditShouldSkipHTTP returns true if the given HTTP request should NOT
	// be audited. The default skips GET, HEAD, and OPTIONS.
	AuditShouldSkipHTTP(method string) bool
}

// DefaultConfig audits only mutating operations.
type DefaultConfig struct{}

func (DefaultConfig) AuditShouldSkipRPC(spec connect.Spec) bool {
	return spec.IdempotencyLevel == connect.IdempotencyIdempotent ||
		spec.IdempotencyLevel == connect.IdempotencyNoSideEffects
}

func (DefaultConfig) AuditShouldSkipHTTP(method string) bool {
	return method == http.MethodGet || method == http.MethodHead || method == http.MethodOptions
}

const meterName = "antinvestor.audit"

// Interceptor is a Connect RPC interceptor that captures audit entries
// for non-idempotent RPCs whose caller is a person.
type Interceptor struct {
	serviceName string
	auditClient auditv1connect.AuditServiceClient
	config      Config
	sender      *sender
}

// NewInterceptor creates an audit interceptor with default config.
//
//   - serviceName: identifies the originating service (e.g. "service_profile").
//     It must equal the service_name claim of the producer's service account;
//     the audit service rejects entries logged under any other name.
//   - auditClient: the audit service client, built with ClientOptions so its
//     timeout is short. If nil, entries are only logged.
func NewInterceptor(serviceName string, auditClient auditv1connect.AuditServiceClient) connect.Interceptor {
	return NewInterceptorWithConfig(serviceName, auditClient, DefaultConfig{})
}

// NewInterceptorWithConfig creates an audit interceptor with explicit configuration.
func NewInterceptorWithConfig(serviceName string, auditClient auditv1connect.AuditServiceClient, cfg Config) connect.Interceptor {
	if cfg == nil {
		cfg = DefaultConfig{}
	}
	return &Interceptor{
		serviceName: serviceName,
		auditClient: auditClient,
		config:      cfg,
		sender:      newSender(serviceName, auditClient),
	}
}

func (a *Interceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		if a.config.AuditShouldSkipRPC(req.Spec()) {
			return next(ctx, req)
		}
		actorCtx := ctx
		start := time.Now()
		ctx = initEntry(ctx)
		if e := entryFromContext(ctx); e != nil {
			e.IPAddress = extractIPAddress(req.Header())
			e.UserAgent = req.Header().Get("User-Agent")
		}

		resp, err := next(ctx, req)

		// The actor is resolved after the handler ran so WithOnBehalfOf is
		// visible; claims come from the original context.
		if actor, ok := ResolveActor(ctx); ok {
			a.sender.record(actorCtx, ctx, actor, req.Spec().Procedure, start, err)
		}
		return resp, err
	}
}

func (a *Interceptor) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (a *Interceptor) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		if a.config.AuditShouldSkipRPC(conn.Spec()) {
			return next(ctx, conn)
		}
		actorCtx := ctx
		start := time.Now()
		ctx = initEntry(ctx)
		if e := entryFromContext(ctx); e != nil {
			e.IPAddress = extractIPAddress(conn.RequestHeader())
			e.UserAgent = conn.RequestHeader().Get("User-Agent")
		}
		err := next(ctx, conn)
		if actor, ok := ResolveActor(ctx); ok {
			a.sender.record(actorCtx, ctx, actor, conn.Spec().Procedure, start, err)
		}
		return err
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Sending
// ─────────────────────────────────────────────────────────────────────────────

// sender logs and sends entries. It is shared by the interceptor and the
// HTTP middleware.
type sender struct {
	serviceName string
	client      auditv1connect.AuditServiceClient
	failures    metric.Int64Counter
	sent        metric.Int64Counter
	tracer      trace.Tracer
}

func newSender(serviceName string, client auditv1connect.AuditServiceClient) *sender {
	meter := otel.Meter(meterName)
	failures, _ := meter.Int64Counter("audit_entry_send_failures_total",
		metric.WithDescription("Audit entries the producer could not deliver"))
	sent, _ := meter.Int64Counter("audit_entry_sent_total",
		metric.WithDescription("Audit entries accepted by the audit service"))
	return &sender{serviceName: serviceName, client: client, failures: failures, sent: sent, tracer: otel.Tracer(meterName)}
}

// record logs the action and sends it synchronously. It never returns an
// error: a failure is logged and counted (soft-fail).
func (s *sender) record(ctx, enriched context.Context, actor Actor, procedure string, start time.Time, callErr error) {
	entry := entryFromContext(enriched)
	req := s.buildRequest(ctx, actor, entry, procedure, callErr)

	fields := map[string]any{
		"audit": true, "service": s.serviceName, "procedure": procedure,
		"action": req.GetAction(), "resource_type": req.GetResourceType(),
		"duration_ms": time.Since(start).Milliseconds(), "success": callErr == nil,
		"profile_id": actor.ProfileID,
	}
	if claims := security.ClaimsFromContext(ctx); claims != nil {
		fields["tenant_id"] = claims.GetTenantID()
		fields["partition_id"] = claims.GetPartitionID()
	}
	if actor.OnBehalfOf != "" {
		fields["on_behalf_of"] = actor.OnBehalfOf
		fields["service_account_id"] = actor.ServiceAccountID
	}
	if req.GetResourceId() != "" {
		fields["resource_id"] = req.GetResourceId()
	}
	if req.GetStateFrom() != "" || req.GetStateTo() != "" {
		fields["state_from"] = req.GetStateFrom()
		fields["state_to"] = req.GetStateTo()
	}
	if callErr != nil {
		fields["error"] = callErr.Error()
	}
	desc := fmt.Sprintf("%s %s", req.GetAction(), req.GetResourceType())
	if callErr != nil {
		desc += " (failed)"
	}
	logger := util.Log(ctx).WithFields(fields)
	defer logger.Release()
	if callErr != nil {
		logger.Warn(desc)
	} else {
		logger.Info(desc)
	}

	if s.client == nil {
		return
	}
	sendCtx, span := s.tracer.Start(ctx, "audit.send")
	defer span.End()
	if _, err := s.client.CreateAuditEntry(sendCtx, connect.NewRequest(req)); err != nil {
		code := connect.CodeOf(err).String()
		s.failures.Add(ctx, 1, metric.WithAttributes(attribute.String("service", s.serviceName), attribute.String("code", code)))
		util.Log(ctx).WithError(err).WithField("audit", true).WithField("code", code).
			Warn("audit entry not delivered; structured log is the only record")
		return
	}
	s.sent.Add(ctx, 1, metric.WithAttributes(attribute.String("service", s.serviceName)))
}

// buildRequest assembles the wire request from the actor, enrichment and
// outcome. No request or response bodies are ever captured.
func (s *sender) buildRequest(ctx context.Context, actor Actor, entry *Entry, procedure string, callErr error) *auditv1.CreateAuditEntryRequest {
	req := &auditv1.CreateAuditEntryRequest{}
	req.SetProfileId(actor.ProfileID)
	req.SetOnBehalfOf(actor.OnBehalfOf)
	req.SetService(s.serviceName)
	req.SetDeviceId(actor.DeviceID)

	action, resourceType := "execute", procedure
	details := map[string]any{}
	if entry != nil {
		if entry.Action != "" {
			action = entry.Action
		}
		if entry.ResourceType != "" {
			resourceType = entry.ResourceType
		}
		req.SetResourceId(entry.ResourceID)
		req.SetResourceVersion(entry.ResourceVersion)
		req.SetTargetProfileId(entry.TargetProfileID)
		req.SetStateFrom(entry.StateFrom)
		req.SetStateTo(entry.StateTo)
		req.SetIpAddress(entry.IPAddress)
		req.SetUserAgent(entry.UserAgent)
		req.SetEntryId(entry.EntryID)
		req.SetCorrelationId(entry.CorrelationID)
		req.SetEventId(entry.EventID)
		req.SetIntentId(entry.IntentID)
		req.SetInstanceId(entry.InstanceID)
		req.SetPayloadHash(entry.PayloadHash)
		req.SetAuthorizationHash(entry.AuthorizationHash)
		req.SetPolicyHash(entry.PolicyHash)
		req.SetDeviceKeyId(entry.DeviceKeyID)
		if !entry.OccurredAt.IsZero() {
			req.SetOccurredAt(timestamppb.New(entry.OccurredAt))
		}
		if len(entry.Relations) > 0 {
			rels := make([]*auditv1.AuditRelation, 0, len(entry.Relations))
			for _, r := range entry.Relations {
				rel := &auditv1.AuditRelation{}
				rel.SetParentType(r.ParentType)
				rel.SetParentId(r.ParentID)
				rel.SetChildType(r.ChildType)
				rel.SetChildId(r.ChildID)
				rel.SetAction(r.Action)
				rels = append(rels, rel)
			}
			req.SetRelations(rels)
		}
		for k, v := range entry.Details {
			details[k] = v
		}
	}
	req.SetAction(action)
	req.SetResourceType(resourceType)
	if callErr != nil {
		details["error"] = callErr.Error()
		details["error_code"] = connect.CodeOf(callErr).String()
	}
	if len(details) > 0 {
		if st, err := structpb.NewStruct(details); err == nil {
			req.SetDetails(st)
		}
	}
	if span := trace.SpanContextFromContext(ctx); span.HasTraceID() {
		req.SetTraceId(span.TraceID().String())
	}
	return req
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// extractIPAddress reads the client IP from standard proxy headers.
func extractIPAddress(h http.Header) string {
	if xff := h.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i > 0 {
			return strings.TrimSpace(xff[:i])
		}
		return strings.TrimSpace(xff)
	}
	if xri := h.Get("X-Real-Ip"); xri != "" {
		return strings.TrimSpace(xri)
	}
	return ""
}
