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
// audit entries to the audit service. Handlers can enrich the audit context
// with resource-specific metadata.
//
// Usage:
//
//	// In service setup:
//	auditClient := auditv1connect.NewAuditServiceClient(httpClient, auditURL)
//	interceptor := audit.NewInterceptor("service_identity", auditClient)
//
//	// In a handler:
//	ctx = audit.WithFields(ctx, audit.Fields{
//	    ResourceType: "organization",
//	    ResourceID:   org.GetId(),
//	})
//	ctx = audit.WithDetail(ctx, "old_state", "CREATED")
//	ctx = audit.WithDetail(ctx, "new_state", "ACTIVE")
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
// Context-based enrichment
// ─────────────────────────────────────────────────────────────────────────────

type contextKey struct{}

// Fields holds audit enrichment data added by handlers via context.
type Fields struct {
	ResourceType    string
	ResourceID      string
	Action          string
	TargetProfileID string
	Details         map[string]any
}

// WithFields attaches audit enrichment data to the context.
//
//	ctx = audit.WithFields(ctx, audit.Fields{
//	    ResourceType: "organization",
//	    ResourceID:   org.GetId(),
//	    Action:       "create",
//	})
func WithFields(ctx context.Context, fields Fields) context.Context {
	return context.WithValue(ctx, contextKey{}, &fields)
}

// WithDetail adds a single key-value detail to the audit context.
// Safe to call multiple times — details accumulate.
//
//	ctx = audit.WithDetail(ctx, "old_state", "CREATED")
//	ctx = audit.WithDetail(ctx, "new_state", "ACTIVE")
func WithDetail(ctx context.Context, key string, value any) context.Context {
	fields := fieldsFromContext(ctx)
	if fields == nil {
		fields = &Fields{Details: map[string]any{}}
		ctx = context.WithValue(ctx, contextKey{}, fields)
	}
	if fields.Details == nil {
		fields.Details = map[string]any{}
	}
	fields.Details[key] = value
	return ctx
}

func fieldsFromContext(ctx context.Context) *Fields {
	val, _ := ctx.Value(contextKey{}).(*Fields)
	return val
}

// ─────────────────────────────────────────────────────────────────────────────
// Interceptor
// ─────────────────────────────────────────────────────────────────────────────

// Interceptor is a Connect RPC interceptor that logs audit entries for
// non-idempotent RPCs and sends them to the audit service.
type Interceptor struct {
	serviceName string
	auditClient auditv1connect.AuditServiceClient
}

// NewInterceptor creates an audit interceptor.
//
//   - serviceName: identifies the originating service (e.g. "service_identity")
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
	enrichment := fieldsFromContext(ctx)

	resourceType, action := ParseProcedure(procedure)
	var resourceID, targetProfileID string

	if enrichment != nil {
		if enrichment.ResourceType != "" {
			resourceType = enrichment.ResourceType
		}
		if enrichment.Action != "" {
			action = enrichment.Action
		}
		resourceID = enrichment.ResourceID
		targetProfileID = enrichment.TargetProfileID
	}

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

	// Send to audit service asynchronously.
	if a.auditClient != nil && profileID != "" {
		go a.send(ctx, profileID, action, resourceType, resourceID,
			deviceID, targetProfileID, enrichment, requestBody, respBody, callErr)
	}
}

func (a *Interceptor) send(
	ctx context.Context,
	profileID, action, resourceType, resourceID,
	deviceID, targetProfileID string,
	enrichment *Fields,
	requestBody, responseBody string,
	callErr error,
) {
	sendCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if claims := security.ClaimsFromContext(ctx); claims != nil {
		sendCtx = claims.ClaimsToContext(sendCtx)
	}

	detailsMap := map[string]any{"service": a.serviceName}
	if requestBody != "" {
		detailsMap["request"] = requestBody
	}
	if responseBody != "" {
		detailsMap["response"] = responseBody
	}
	if callErr != nil {
		detailsMap["error"] = callErr.Error()
	}
	if enrichment != nil {
		for k, v := range enrichment.Details {
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
// e.g. "/identity.v1.IdentityService/OrganizationSave" → ("Organization", "Save")
func ParseProcedure(procedure string) (string, string) {
	parts := strings.Split(procedure, "/")
	method := parts[len(parts)-1]
	for _, suffix := range []string{
		"Save", "Create", "Delete", "Update",
		"Submit", "Approve", "Reject", "Cancel",
		"Record", "Apply", "Complete", "Manage",
		"Verify", "Publish", "Deposit", "Withdraw",
		"Transfer", "Reassign", "Merge",
	} {
		if strings.HasSuffix(method, suffix) {
			return method[:len(method)-len(suffix)], suffix
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
