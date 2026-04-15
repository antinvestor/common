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

package audit

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	"connectrpc.com/connect"
	"github.com/pitabwire/frame/security"
	"github.com/pitabwire/util"
	"google.golang.org/protobuf/types/known/structpb"
)

// HTTPMiddleware returns an http.Handler middleware that audits REST API calls.
//
// It captures the same information as the Connect RPC Interceptor:
// actor (from JWT claims), method, path, request body, response status,
// duration, IP address, user agent, and any handler enrichment via context.
//
// Handlers can enrich the audit context using the same With* functions:
//
//	func myHandler(w http.ResponseWriter, r *http.Request) {
//	    audit.WithResource(r.Context(), "profile", profileID)
//	    audit.WithDetail(r.Context(), "action", "export")
//	    // ...
//	}
//
// Usage:
//
//	auditedHandler := audit.HTTPMiddleware("service_profile", auditClient)(myHandler)
func HTTPMiddleware(
	serviceName string,
	auditClient auditv1connect.AuditServiceClient,
) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip internal calls and read-only GET/HEAD/OPTIONS.
			if shouldSkipHTTP(r) {
				next.ServeHTTP(w, r)
				return
			}

			start := time.Now()

			// Pre-populate audit entry in context.
			ctx := initEntry(r.Context())
			if e := entryFromContext(ctx); e != nil {
				e.IPAddress = extractIPAddress(r.Header)
				e.UserAgent = r.UserAgent()
			}
			r = r.WithContext(ctx)

			// Capture request body for mutating requests.
			var reqBody string
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				reqBody = captureRequestBody(r)
			}

			// Wrap response writer to capture status code.
			rw := &statusWriter{ResponseWriter: w, statusCode: http.StatusOK}

			next.ServeHTTP(rw, r)

			// Record the audit entry.
			recordHTTPEntry(
				r.Context(),
				serviceName,
				auditClient,
				r.Method,
				r.URL.Path,
				start,
				reqBody,
				rw.statusCode,
			)
		})
	}
}

// shouldSkipHTTP returns true for requests that shouldn't be audited.
func shouldSkipHTTP(r *http.Request) bool {
	// Skip safe methods.
	switch r.Method {
	case http.MethodGet, http.MethodHead, http.MethodOptions:
		return true
	}
	// Skip internal system calls.
	claims := security.ClaimsFromContext(r.Context())
	return claims != nil && claims.IsInternalSystem()
}

// statusWriter wraps http.ResponseWriter to capture the status code.
type statusWriter struct {
	http.ResponseWriter
	statusCode int
	written    bool
}

func (sw *statusWriter) WriteHeader(code int) {
	if !sw.written {
		sw.statusCode = code
		sw.written = true
	}
	sw.ResponseWriter.WriteHeader(code)
}

func (sw *statusWriter) Write(b []byte) (int, error) {
	if !sw.written {
		sw.written = true
	}
	return sw.ResponseWriter.Write(b)
}

// captureRequestBody reads and restores the request body (up to 4KB).
func captureRequestBody(r *http.Request) string {
	if r.Body == nil {
		return ""
	}
	const maxLen = 4096
	buf := make([]byte, maxLen+1)
	n, _ := io.ReadFull(r.Body, buf)
	_ = r.Body.Close()

	// Restore the body for the handler.
	if n > 0 {
		if n > maxLen {
			r.Body = io.NopCloser(io.MultiReader(
				bytes.NewReader(buf[:maxLen]),
				strings.NewReader("...(truncated)"),
			))
			return string(buf[:maxLen]) + "...(truncated)"
		}
		r.Body = io.NopCloser(bytes.NewReader(buf[:n]))
		return string(buf[:n])
	}
	r.Body = io.NopCloser(bytes.NewReader(nil))
	return ""
}

// recordHTTPEntry logs and sends the audit entry for an HTTP request.
func recordHTTPEntry(
	ctx context.Context,
	serviceName string,
	auditClient auditv1connect.AuditServiceClient,
	method, path string,
	start time.Time,
	reqBody string,
	statusCode int,
) {
	claims := security.ClaimsFromContext(ctx)
	entry := entryFromContext(ctx)

	// Resource type and action come from handler enrichment.
	var resourceType, action, resourceID, targetProfileID, ipAddr, userAgent string
	if entry != nil {
		resourceType = entry.ResourceType
		action = entry.Action
		resourceID = entry.ResourceID
		targetProfileID = entry.TargetProfileID
		ipAddr = entry.IPAddress
		userAgent = entry.UserAgent
	}
	if resourceType == "" {
		resourceType = path
	}
	if action == "" {
		action = method
	}

	success := statusCode >= 200 && statusCode < 400

	// Structured log.
	fields := map[string]any{
		"audit":         true,
		"service":       serviceName,
		"http_method":   method,
		"http_path":     path,
		"http_status":   statusCode,
		"action":        action,
		"resource_type": resourceType,
		"duration_ms":   time.Since(start).Milliseconds(),
		"success":       success,
	}

	var profileID, deviceID string
	if claims != nil {
		profileID = claims.GetProfileID()
		deviceID = claims.GetDeviceID()
		fields["profile_id"] = profileID
		fields["tenant_id"] = claims.GetTenantID()
		fields["partition_id"] = claims.GetPartitionID()
		fields["session_id"] = claims.GetSessionID()
		fields["device_id"] = deviceID
	}

	if resourceID != "" {
		fields["resource_id"] = resourceID
	}
	if ipAddr != "" {
		fields["ip_address"] = ipAddr
	}
	if userAgent != "" {
		fields["user_agent"] = userAgent
	}
	if reqBody != "" {
		fields["request"] = reqBody
	}

	desc := fmt.Sprintf("%s %s %s [%d]", method, action, resourceType, statusCode)

	logger := util.Log(ctx).WithFields(fields)
	defer logger.Release()
	if !success {
		logger.Warn(desc)
	} else {
		logger.Info(desc)
	}

	// Send to audit service.
	if auditClient != nil && profileID != "" {
		go sendHTTPEntry(ctx, auditClient, serviceName, profileID,
			action, resourceType, resourceID, deviceID,
			targetProfileID, ipAddr, userAgent, entry,
			method, path, reqBody, statusCode)
	}
}

func sendHTTPEntry(
	ctx context.Context,
	auditClient auditv1connect.AuditServiceClient,
	serviceName, profileID, action, resourceType, resourceID,
	deviceID, targetProfileID, ipAddr, userAgent string,
	entry *Entry,
	method, path, reqBody string,
	statusCode int,
) {
	sendCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if claims := security.ClaimsFromContext(ctx); claims != nil {
		sendCtx = claims.ClaimsToContext(sendCtx)
	}

	detailsMap := map[string]any{
		"service":     serviceName,
		"http_method": method,
		"http_path":   path,
		"http_status": statusCode,
	}
	if reqBody != "" {
		detailsMap["request"] = reqBody
	}
	if entry != nil {
		if entry.StateFrom != "" {
			detailsMap["state_from"] = entry.StateFrom
		}
		if entry.StateTo != "" {
			detailsMap["state_to"] = entry.StateTo
		}
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
		Service:         serviceName,
		Details:         details,
		IpAddress:       ipAddr,
		UserAgent:       userAgent,
		DeviceId:        deviceID,
		TargetProfileId: targetProfileID,
	}

	_, _ = auditClient.CreateAuditEntry(sendCtx, connect.NewRequest(req))
}

