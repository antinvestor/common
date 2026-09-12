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

package audit_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"connectrpc.com/connect"
	"github.com/antinvestor/common/audit"
	"github.com/pitabwire/frame/v2/security"
	"github.com/stretchr/testify/require"
)

// recordingAuditService is an in-process audit service that stores what
// producers send and can be told to fail.
type recordingAuditService struct {
	auditv1connect.UnimplementedAuditServiceHandler
	mu       sync.Mutex
	received []*auditv1.CreateAuditEntryRequest
	fail     bool
	delay    time.Duration
}

func (r *recordingAuditService) CreateAuditEntry(ctx context.Context, req *connect.Request[auditv1.CreateAuditEntryRequest]) (*connect.Response[auditv1.CreateAuditEntryResponse], error) {
	if r.delay > 0 {
		select {
		case <-time.After(r.delay):
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.fail {
		return nil, connect.NewError(connect.CodeUnavailable, errors.New("down"))
	}
	r.received = append(r.received, req.Msg)
	resp := &auditv1.CreateAuditEntryResponse{}
	resp.SetIntakeId("intake-1")
	resp.SetEntryId(req.Msg.GetEntryId())
	resp.SetState(auditv1.IntakeState_INTAKE_STATE_ACCEPTED)
	return connect.NewResponse(resp), nil
}

func (r *recordingAuditService) entries() []*auditv1.CreateAuditEntryRequest {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]*auditv1.CreateAuditEntryRequest(nil), r.received...)
}

func newAuditServer(t *testing.T) (*recordingAuditService, auditv1connect.AuditServiceClient) {
	t.Helper()
	svc := &recordingAuditService{}
	_, h := auditv1connect.NewAuditServiceHandler(svc)
	server := httptest.NewServer(h)
	t.Cleanup(server.Close)
	client := auditv1connect.NewAuditServiceClient(&http.Client{Timeout: audit.ClientTimeout}, server.URL)
	return svc, client
}

// producer is a minimal Connect service wrapped by the audit interceptor.
type producer struct {
	auditv1connect.UnimplementedAuditServiceHandler
	handle func(ctx context.Context) error
}

// We reuse the audit proto as the "producer" API for convenience:
// RegisterAuditManifest is a mutating RPC, GetAuditManifest is
// NO_SIDE_EFFECTS.
func (p *producer) RegisterAuditManifest(ctx context.Context, _ *connect.Request[auditv1.RegisterAuditManifestRequest]) (*connect.Response[auditv1.RegisterAuditManifestResponse], error) {
	if err := p.handle(ctx); err != nil {
		return nil, err
	}
	return connect.NewResponse(&auditv1.RegisterAuditManifestResponse{}), nil
}

func (p *producer) GetAuditManifest(ctx context.Context, _ *connect.Request[auditv1.GetAuditManifestRequest]) (*connect.Response[auditv1.GetAuditManifestResponse], error) {
	if err := p.handle(ctx); err != nil {
		return nil, err
	}
	return connect.NewResponse(&auditv1.GetAuditManifestResponse{}), nil
}

// claimsFromHeader stands in for the auth interceptor.
type claimsFromHeader struct{}

func (claimsFromHeader) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		h := req.Header()
		if h.Get("X-Profile") != "" {
			claims := &security.AuthenticationClaims{
				TenantID: "t1", PartitionID: "p1", ProfileID: h.Get("X-Profile"), DeviceID: "dev-1",
				Roles: []string{h.Get("X-Role")}, Ext: map[string]any{},
			}
			claims.Subject = claims.ProfileID
			if sa := h.Get("X-SA"); sa != "" {
				claims.Ext["service_account_id"] = sa
			}
			ctx = claims.ClaimsToContext(ctx)
		}
		return next(ctx, req)
	}
}
func (claimsFromHeader) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}
func (claimsFromHeader) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return next
}

func newProducer(t *testing.T, interceptor connect.Interceptor, handle func(ctx context.Context) error) auditv1connect.AuditServiceClient {
	t.Helper()
	_, h := auditv1connect.NewAuditServiceHandler(&producer{handle: handle}, connect.WithInterceptors(claimsFromHeader{}, interceptor))
	server := httptest.NewServer(h)
	t.Cleanup(server.Close)
	return auditv1connect.NewAuditServiceClient(server.Client(), server.URL)
}

func mutating(profile, role, sa string) *connect.Request[auditv1.RegisterAuditManifestRequest] {
	req := connect.NewRequest(&auditv1.RegisterAuditManifestRequest{})
	req.Header().Set("X-Profile", profile)
	req.Header().Set("X-Role", role)
	req.Header().Set("X-SA", sa)
	req.Header().Set("X-Forwarded-For", "203.0.113.9, 10.0.0.1")
	req.Header().Set("User-Agent", "test-ua")
	return req
}

func TestInterceptor_ActorRule(t *testing.T) {
	cases := []struct {
		name       string
		profile    string
		role       string
		sa         string
		onBehalfOf string
		wantEntry  bool
		wantActor  string
		wantOBO    string
	}{
		{name: "user token is audited", profile: "person-1", role: "user", wantEntry: true, wantActor: "person-1"},
		{name: "root admin with internal role is audited", profile: "root-admin", role: "internal", wantEntry: true, wantActor: "root-admin"},
		{name: "service account is skipped", profile: "sa-profile", role: "system_internal", sa: "sa-1"},
		{name: "service account acting for a person", profile: "sa-profile", role: "system_internal", sa: "sa-1", onBehalfOf: "member-7", wantEntry: true, wantActor: "member-7", wantOBO: "member-7"},
		{name: "unauthenticated is skipped"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			svc, client := newAuditServer(t)
			interceptor := audit.NewInterceptor("service_loans", client)
			p := newProducer(t, interceptor, func(ctx context.Context) error {
				audit.WithResource(ctx, "loan", "loan-1")
				audit.WithAction(ctx, "approve")
				audit.WithDetail(ctx, "reason", "ok")
				if tc.onBehalfOf != "" {
					audit.WithOnBehalfOf(ctx, tc.onBehalfOf)
				}
				return nil
			})
			_, err := p.RegisterAuditManifest(context.Background(), mutating(tc.profile, tc.role, tc.sa))
			require.NoError(t, err)

			got := svc.entries()
			if !tc.wantEntry {
				require.Empty(t, got)
				return
			}
			require.Len(t, got, 1)
			e := got[0]
			require.Equal(t, tc.wantActor, e.GetProfileId())
			require.Equal(t, tc.wantOBO, e.GetOnBehalfOf())
			require.Equal(t, "service_loans", e.GetService())
			require.Equal(t, "approve", e.GetAction())
			require.Equal(t, "loan", e.GetResourceType())
			require.Equal(t, "loan-1", e.GetResourceId())
			require.Equal(t, "203.0.113.9", e.GetIpAddress())
			require.Equal(t, "test-ua", e.GetUserAgent())
			require.Equal(t, "dev-1", e.GetDeviceId())
			require.Equal(t, "ok", e.GetDetails().AsMap()["reason"])
		})
	}
}

func TestInterceptor_SkipsIdempotentAndRecordsFailures(t *testing.T) {
	svc, client := newAuditServer(t)
	interceptor := audit.NewInterceptor("service_loans", client)
	p := newProducer(t, interceptor, func(ctx context.Context) error {
		if audit.OnBehalfOfFromContext(ctx) == "boom" {
			return connect.NewError(connect.CodeFailedPrecondition, errors.New("nope"))
		}
		return nil
	})

	get := connect.NewRequest(&auditv1.GetAuditManifestRequest{})
	get.Header().Set("X-Profile", "person-1")
	_, err := p.GetAuditManifest(context.Background(), get)
	require.NoError(t, err)
	require.Empty(t, svc.entries(), "NO_SIDE_EFFECTS RPCs are not audited")

	// A failed mutating call is still audited, with the error recorded.
	_, err = p.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.NoError(t, err)
	failing := newProducer(t, audit.NewInterceptor("service_loans", client), func(ctx context.Context) error {
		return connect.NewError(connect.CodeFailedPrecondition, errors.New("nope"))
	})
	_, err = failing.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
	got := svc.entries()
	require.Len(t, got, 2)
	require.Equal(t, "failed_precondition", got[1].GetDetails().AsMap()["error_code"])
}

func TestInterceptor_SoftFailsWhenAuditServiceIsDown(t *testing.T) {
	svc, client := newAuditServer(t)
	svc.fail = true
	p := newProducer(t, audit.NewInterceptor("service_loans", client), func(context.Context) error { return nil })
	start := time.Now()
	_, err := p.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.NoError(t, err, "producer call succeeds even when audit is unavailable")
	require.Less(t, time.Since(start), audit.ClientTimeout)

	// A hung audit service is bounded by the client timeout, synchronously.
	svc.fail = false
	svc.delay = 5 * time.Second
	start = time.Now()
	_, err = p.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.NoError(t, err)
	elapsed := time.Since(start)
	require.GreaterOrEqual(t, elapsed, audit.ClientTimeout-100*time.Millisecond)
	require.Less(t, elapsed, 4*time.Second)

	// A nil client only logs.
	logOnly := newProducer(t, audit.NewInterceptor("service_loans", nil), func(context.Context) error { return nil })
	_, err = logOnly.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.NoError(t, err)
}

func TestInterceptor_EvidenceFieldsAndRelations(t *testing.T) {
	svc, client := newAuditServer(t)
	at := time.Date(2026, 9, 12, 10, 0, 0, 0, time.UTC)
	p := newProducer(t, audit.NewInterceptor("service_finance", client), func(ctx context.Context) error {
		audit.WithIntent(ctx, "intent-1", "aa", "bb", "cc")
		audit.WithEvent(ctx, "evt-1")
		audit.WithInstance(ctx, "wf-1")
		audit.WithCorrelation(ctx, "corr-1")
		audit.WithEntryID(ctx, "entry-1")
		audit.WithDeviceKey(ctx, "dk-1")
		audit.WithOccurredAt(ctx, at)
		audit.WithResourceVersion(ctx, 9)
		audit.WithStateChange(ctx, "OPEN", "PASSED")
		audit.WithTarget(ctx, "member-2")
		audit.WithRelation(ctx, audit.Relation{ParentType: "group", ParentID: "g1", ChildType: "member", ChildID: "m1", Action: audit.RelationAdded})
		return nil
	})
	_, err := p.RegisterAuditManifest(context.Background(), mutating("person-1", "user", ""))
	require.NoError(t, err)
	got := svc.entries()
	require.Len(t, got, 1)
	e := got[0]
	require.Equal(t, "intent-1", e.GetIntentId())
	require.Equal(t, "aa", e.GetPayloadHash())
	require.Equal(t, "bb", e.GetAuthorizationHash())
	require.Equal(t, "cc", e.GetPolicyHash())
	require.Equal(t, "evt-1", e.GetEventId())
	require.Equal(t, "wf-1", e.GetInstanceId())
	require.Equal(t, "corr-1", e.GetCorrelationId())
	require.Equal(t, "entry-1", e.GetEntryId())
	require.Equal(t, "dk-1", e.GetDeviceKeyId())
	require.Equal(t, at, e.GetOccurredAt().AsTime())
	require.Equal(t, int64(9), e.GetResourceVersion())
	require.Equal(t, "OPEN", e.GetStateFrom())
	require.Equal(t, "PASSED", e.GetStateTo())
	require.Equal(t, "member-2", e.GetTargetProfileId())
	require.Len(t, e.GetRelations(), 1)
	require.Equal(t, "member", e.GetRelations()[0].GetChildType())
	require.Equal(t, "execute", e.GetAction(), "no action override falls back to execute")
	require.Contains(t, e.GetResourceType(), "RegisterAuditManifest", "no resource override falls back to the procedure")
}

func TestHTTPMiddleware_AuditsMutatingRequestsForPeople(t *testing.T) {
	svc, client := newAuditServer(t)
	handler := audit.HTTPMiddleware("service_files", client)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		audit.WithResource(r.Context(), "file", "f-1")
		if r.URL.Path == "/fail" {
			w.WriteHeader(http.StatusConflict)
			return
		}
		w.WriteHeader(http.StatusCreated)
	}))
	withClaims := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if p := r.Header.Get("X-Profile"); p != "" {
				claims := &security.AuthenticationClaims{TenantID: "t1", ProfileID: p}
				claims.Subject = p
				r = r.WithContext(claims.ClaimsToContext(r.Context()))
			}
			next.ServeHTTP(w, r)
		})
	}
	server := httptest.NewServer(withClaims(handler))
	t.Cleanup(server.Close)

	do := func(method, path, profile string) int {
		req, _ := http.NewRequestWithContext(context.Background(), method, server.URL+path, http.NoBody)
		if profile != "" {
			req.Header.Set("X-Profile", profile)
		}
		resp, err := server.Client().Do(req)
		require.NoError(t, err)
		resp.Body.Close()
		return resp.StatusCode
	}
	require.Equal(t, http.StatusCreated, do(http.MethodGet, "/ok", "person-1"))
	require.Empty(t, svc.entries(), "GET is not audited")
	require.Equal(t, http.StatusCreated, do(http.MethodPost, "/ok", ""))
	require.Empty(t, svc.entries(), "anonymous is not audited")
	require.Equal(t, http.StatusCreated, do(http.MethodPost, "/ok", "person-1"))
	require.Equal(t, http.StatusConflict, do(http.MethodPost, "/fail", "person-1"))
	got := svc.entries()
	require.Len(t, got, 2)
	require.Equal(t, "POST", got[0].GetAction())
	require.Equal(t, "file", got[0].GetResourceType())
	require.Equal(t, "f-1", got[0].GetResourceId())
	require.Equal(t, "http 409", got[1].GetDetails().AsMap()["error"])
}

func TestNewManifest_BuildsRequest(t *testing.T) {
	req := audit.NewManifest("service_loans", []string{audit.ActionCreate}, []string{audit.ResourceLoanAccount},
		audit.AllowBackdating(), audit.ExtraForbiddenKeys("national_id"))
	m := req.GetManifest()
	require.Equal(t, "service_loans", m.GetService())
	require.Equal(t, []string{"create"}, m.GetActions())
	require.True(t, m.GetAllowBackdating())
	require.False(t, m.GetOpenVocabulary())
	require.Equal(t, []string{"national_id"}, m.GetExtraForbiddenKeys())
}
