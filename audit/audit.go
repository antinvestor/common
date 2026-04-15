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

// Package audit provides a reusable Connect RPC interceptor for audit logging.
//
// The interceptor captures all non-idempotent RPC calls and sends structured
// audit entries to the audit service. Handlers enrich the audit context with
// resource-specific metadata using the With* functions.
//
// # Basic usage
//
//	interceptor := audit.NewInterceptor("service_profile", auditClient)
//
// # Handler enrichment
//
//	// Identify the resource being acted on.
//	ctx = audit.WithResource(ctx, "organization", org.GetId())
//
//	// Record a state transition.
//	ctx = audit.WithStateChange(ctx, "CREATED", "ACTIVE")
//
//	// Record a relationship change (e.g. contact added to profile).
//	ctx = audit.WithRelation(ctx, audit.Relation{
//	    ParentType: "profile",
//	    ParentID:   profileID,
//	    ChildType:  "contact",
//	    ChildID:    contactID,
//	    Action:     "added",
//	})
//
//	// Add arbitrary key-value details.
//	ctx = audit.WithDetail(ctx, "reason", "customer request")
//	ctx = audit.WithDetail(ctx, "approved_by", approverID)
package audit

import (
	"context"
	"fmt"
	"reflect"
	"strings"
	"time"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	"connectrpc.com/connect"
	"github.com/pitabwire/frame/security"
	"github.com/pitabwire/util"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/structpb"
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

	// Override the auto-detected action (e.g. "approve" instead of "Save").
	Action string

	// Profile ID of the target user, if the action affects another user.
	TargetProfileID string

	// State transition (e.g. CREATED → ACTIVE).
	StateFrom string
	StateTo   string

	// Relationships created or modified during this action.
	Relations []Relation

	// Arbitrary key-value details.
	Details map[string]any
}

// Relation represents a link between two entities that was created,
// modified, or removed during the audited action.
type Relation struct {
	ParentType string // e.g. "profile"
	ParentID   string // e.g. "d75qclkpf2t1uum8ij3g"
	ChildType  string // e.g. "contact"
	ChildID    string // e.g. "d7eloa0jbutr739k3qmg"
	Action     string // e.g. "added", "removed", "updated"
}

func entryFromContext(ctx context.Context) *Entry {
	val, _ := ctx.Value(contextKey{}).(*Entry)
	return val
}

func ensureEntry(ctx context.Context) (context.Context, *Entry) {
	e := entryFromContext(ctx)
	if e == nil {
		e = &Entry{Details: map[string]any{}}
		ctx = context.WithValue(ctx, contextKey{}, e)
	}
	return ctx, e
}

// WithResource identifies the primary resource being acted on.
//
//	ctx = audit.WithResource(ctx, "organization", org.GetId())
func WithResource(ctx context.Context, resourceType, resourceID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.ResourceType = resourceType
	e.ResourceID = resourceID
	return ctx
}

// WithAction overrides the auto-detected action name.
//
//	ctx = audit.WithAction(ctx, "approve")
func WithAction(ctx context.Context, action string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.Action = action
	return ctx
}

// WithTarget sets the target profile affected by this action.
//
//	ctx = audit.WithTarget(ctx, memberProfileID)
func WithTarget(ctx context.Context, targetProfileID string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.TargetProfileID = targetProfileID
	return ctx
}

// WithStateChange records a state transition on the resource.
//
//	ctx = audit.WithStateChange(ctx, "CREATED", "ACTIVE")
func WithStateChange(ctx context.Context, fromState, toState string) context.Context {
	ctx, e := ensureEntry(ctx)
	e.StateFrom = fromState
	e.StateTo = toState
	return ctx
}

// WithRelation records a relationship created, modified, or removed.
// Call multiple times for multiple relationships in a single action.
//
//	ctx = audit.WithRelation(ctx, audit.Relation{
//	    ParentType: "profile",
//	    ParentID:   profileID,
//	    ChildType:  "contact",
//	    ChildID:    contactID,
//	    Action:     "added",
//	})
func WithRelation(ctx context.Context, rel Relation) context.Context {
	ctx, e := ensureEntry(ctx)
	e.Relations = append(e.Relations, rel)
	return ctx
}

// WithDetail adds a single key-value detail. Safe to call multiple times.
//
//	ctx = audit.WithDetail(ctx, "reason", "compliance review")
//	ctx = audit.WithDetail(ctx, "old_name", oldName)
//	ctx = audit.WithDetail(ctx, "new_name", newName)
func WithDetail(ctx context.Context, key string, value any) context.Context {
	ctx, e := ensureEntry(ctx)
	if e.Details == nil {
		e.Details = map[string]any{}
	}
	e.Details[key] = value
	return ctx
}

// ─────────────────────────────────────────────────────────────────────────────
// Interceptor
// ─────────────────────────────────────────────────────────────────────────────

// Interceptor is a Connect RPC interceptor that captures audit entries
// for non-idempotent RPCs and sends them to the audit service.
type Interceptor struct {
	serviceName string
	auditClient auditv1connect.AuditServiceClient
}

// NewInterceptor creates an audit interceptor.
//
//   - serviceName: identifies the originating service (e.g. "service_profile")
//   - auditClient: the audit service client. If nil, entries are only logged.
func NewInterceptor(serviceName string, auditClient auditv1connect.AuditServiceClient) connect.Interceptor {
	return &Interceptor{
		serviceName: serviceName,
		auditClient: auditClient,
	}
}

func (a *Interceptor) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		if shouldSkip(ctx) {
			return next(ctx, req)
		}

		readOnly := isReadOnly(req.Spec())
		start := time.Now()
		procedure := req.Spec().Procedure

		var reqSnapshot string
		if !readOnly {
			reqSnapshot = marshalProto(req.Any())
		}

		resp, err := next(ctx, req)

		if !readOnly || err != nil {
			if readOnly && reqSnapshot == "" {
				reqSnapshot = marshalProto(req.Any())
			}
			a.record(ctx, procedure, start, reqSnapshot, resp, err)
		}

		return resp, err
	}
}

func (a *Interceptor) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (a *Interceptor) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		if shouldSkip(ctx) {
			return next(ctx, conn)
		}

		readOnly := isReadOnly(conn.Spec())
		start := time.Now()
		err := next(ctx, conn)

		if !readOnly || err != nil {
			a.record(ctx, conn.Spec().Procedure, start, "", nil, err)
		}

		return err
	}
}

func shouldSkip(ctx context.Context) bool {
	claims := security.ClaimsFromContext(ctx)
	return claims != nil && claims.IsInternalSystem()
}

func isReadOnly(spec connect.Spec) bool {
	return spec.IdempotencyLevel == connect.IdempotencyIdempotent ||
		spec.IdempotencyLevel == connect.IdempotencyNoSideEffects
}

func (a *Interceptor) record(
	ctx context.Context,
	procedure string,
	start time.Time,
	requestBody string,
	resp connect.AnyResponse,
	callErr error,
) {
	claims := security.ClaimsFromContext(ctx)
	entry := entryFromContext(ctx)

	// Determine resource type and action from procedure or enrichment.
	resourceType, action := ParseProcedure(procedure)
	var resourceID, targetProfileID, stateFrom, stateTo string

	if entry != nil {
		if entry.ResourceType != "" {
			resourceType = entry.ResourceType
		}
		if entry.Action != "" {
			action = entry.Action
		}
		resourceID = entry.ResourceID
		targetProfileID = entry.TargetProfileID
		stateFrom = entry.StateFrom
		stateTo = entry.StateTo
	}

	// Build structured log fields.
	fields := map[string]any{
		"audit":         true,
		"service":       a.serviceName,
		"procedure":     procedure,
		"action":        action,
		"resource_type": resourceType,
		"duration_ms":   time.Since(start).Milliseconds(),
		"success":       callErr == nil,
	}

	var profileID, deviceID string
	if claims != nil {
		profileID = claims.GetProfileID()
		deviceID = claims.GetDeviceID()
		fields["profile_id"] = profileID
		fields["tenant_id"] = claims.GetTenantID()
		fields["partition_id"] = claims.GetPartitionID()
		fields["access_id"] = claims.GetAccessID()
		fields["session_id"] = claims.GetSessionID()
		fields["device_id"] = deviceID
		fields["roles"] = claims.GetRoles()
	}

	if resourceID != "" {
		fields["resource_id"] = resourceID
	}
	if stateFrom != "" || stateTo != "" {
		fields["state_from"] = stateFrom
		fields["state_to"] = stateTo
	}
	if requestBody != "" {
		fields["request"] = requestBody
	}
	respBody := marshalResponse(resp)
	if respBody != "" {
		fields["response"] = respBody
	}
	if callErr != nil {
		fields["error"] = callErr.Error()
	}

	desc := fmt.Sprintf("%s %s", action, resourceType)
	if stateFrom != "" && stateTo != "" {
		desc += fmt.Sprintf(" (%s → %s)", stateFrom, stateTo)
	}
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

	// Send to audit service asynchronously (best-effort).
	if a.auditClient != nil && profileID != "" {
		go a.send(ctx, profileID, action, resourceType, resourceID,
			deviceID, targetProfileID, entry, requestBody, respBody, callErr)
	}
}

func (a *Interceptor) send(
	ctx context.Context,
	profileID, action, resourceType, resourceID,
	deviceID, targetProfileID string,
	entry *Entry,
	requestBody, responseBody string,
	callErr error,
) {
	sendCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if claims := security.ClaimsFromContext(ctx); claims != nil {
		sendCtx = claims.ClaimsToContext(sendCtx)
	}

	// Build details — everything goes into one Struct for the audit service.
	detailsMap := map[string]any{
		"service": a.serviceName,
	}
	if requestBody != "" {
		detailsMap["request"] = requestBody
	}
	if responseBody != "" {
		detailsMap["response"] = responseBody
	}
	if callErr != nil {
		detailsMap["error"] = callErr.Error()
	}

	// State change.
	if entry != nil {
		if entry.StateFrom != "" {
			detailsMap["state_from"] = entry.StateFrom
		}
		if entry.StateTo != "" {
			detailsMap["state_to"] = entry.StateTo
		}

		// Relations — stored as a list of maps for queryability.
		if len(entry.Relations) > 0 {
			rels := make([]any, 0, len(entry.Relations))
			for _, r := range entry.Relations {
				rels = append(rels, map[string]any{
					"parent_type": r.ParentType,
					"parent_id":   r.ParentID,
					"child_type":  r.ChildType,
					"child_id":    r.ChildID,
					"action":      r.Action,
				})
			}
			detailsMap["relations"] = rels
		}

		// Handler-provided details.
		for k, v := range entry.Details {
			detailsMap[k] = v
		}
	}

	details, err := structpb.NewStruct(detailsMap)
	if err != nil {
		return
	}

	req := &auditv1.CreateAuditEntryRequest{
		ProfileId:       profileID,
		Action:          action,
		ResourceType:    resourceType,
		ResourceId:      resourceID,
		Service:         a.serviceName,
		Details:         details,
		DeviceId:        deviceID,
		TargetProfileId: targetProfileID,
	}

	_, _ = a.auditClient.CreateAuditEntry(sendCtx, connect.NewRequest(req))
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// ParseProcedure extracts resource type and action from a Connect procedure.
// e.g. "/profile.v1.ProfileService/AddContact" → ("Contact", "Add")
func ParseProcedure(procedure string) (string, string) {
	parts := strings.Split(procedure, "/")
	method := parts[len(parts)-1]
	for _, suffix := range []string{
		"Save", "Create", "Delete", "Update", "Remove",
		"Submit", "Approve", "Reject", "Cancel",
		"Record", "Apply", "Complete", "Manage",
		"Verify", "Publish", "Deposit", "Withdraw",
		"Transfer", "Reassign", "Merge",
	} {
		if strings.HasSuffix(method, suffix) {
			return method[:len(method)-len(suffix)], suffix
		}
	}
	// Try prefix-based actions (Add*, Get*, List*, Search*).
	for _, prefix := range []string{
		"Add", "Set", "Check", "Batch",
	} {
		if strings.HasPrefix(method, prefix) {
			return method[len(prefix):], prefix
		}
	}
	return method, "Execute"
}

func marshalProto(msg any) string {
	pm, ok := msg.(proto.Message)
	if !ok || pm == nil {
		return ""
	}
	b, err := protojson.MarshalOptions{EmitUnpopulated: false, UseProtoNames: true}.Marshal(pm)
	if err != nil {
		return ""
	}
	s := string(b)
	if len(s) > 4096 {
		return s[:4096] + "...(truncated)"
	}
	return s
}

func marshalResponse(resp connect.AnyResponse) string {
	if resp == nil {
		return ""
	}
	val := reflect.ValueOf(resp)
	switch val.Kind() { //nolint:exhaustive
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		if val.IsNil() {
			return ""
		}
	}
	if msg := resp.Any(); msg != nil {
		return marshalProto(msg)
	}
	return ""
}
