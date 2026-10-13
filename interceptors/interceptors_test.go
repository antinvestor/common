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

package interceptors_test

import (
	"context"
	"errors"
	"io"
	"sync"
	"testing"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connectinprocess"
	"github.com/pitabwire/util"
	"golang.org/x/oauth2"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/wrapperspb"

	"github.com/antinvestor/common/v3/interceptors"
)

var (
	unarySpec  = connect.Spec{StreamType: connect.StreamTypeUnary, Procedure: "/test.v1.TestService/Ping"}
	streamSpec = connect.Spec{StreamType: connect.StreamTypeServer, Procedure: "/test.v1.TestService/Watch"}
	failSpec   = connect.Spec{StreamType: connect.StreamTypeUnary, Procedure: "/test.v1.TestService/Fail"}
)

const streamMessages = 3

// headerRecorder keeps the request headers of the last RPC the server saw.
type headerRecorder struct {
	mu     sync.Mutex
	header map[string]string
	calls  int
}

func (r *headerRecorder) record(ctx context.Context) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.calls++
	r.header = map[string]string{}
	if info, ok := connect.CallInfoForServerContext(ctx); ok {
		for name, values := range info.RequestHeader().All() {
			if len(values) > 0 {
				r.header[name] = values[0]
			}
		}
	}
}

func (r *headerRecorder) get(name string) string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.header[name]
}

func (r *headerRecorder) count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.calls
}

func newTestClient(
	t *testing.T,
	serverInterceptors []connect.ServerInterceptor,
	clientInterceptors ...connect.ClientInterceptor,
) (*connect.Client, *headerRecorder) {
	t.Helper()

	rec := &headerRecorder{}
	server := connect.NewServer(serverInterceptors...)
	server.Register(
		connect.Method{
			Spec: unarySpec,
			Handler: func(ctx context.Context, _ connect.Spec, stream connect.ServerStream) error {
				rec.record(ctx)
				var req emptypb.Empty
				if err := stream.Receive(&req); err != nil {
					return err
				}
				return stream.Send(&emptypb.Empty{})
			},
		},
		connect.Method{
			Spec: streamSpec,
			Handler: func(ctx context.Context, _ connect.Spec, stream connect.ServerStream) error {
				rec.record(ctx)
				var req emptypb.Empty
				if err := stream.Receive(&req); err != nil {
					return err
				}
				for range streamMessages {
					if err := stream.Send(wrapperspb.String("event")); err != nil {
						return err
					}
				}
				return nil
			},
		},
		connect.Method{
			Spec: failSpec,
			Handler: func(ctx context.Context, _ connect.Spec, stream connect.ServerStream) error {
				rec.record(ctx)
				var req emptypb.Empty
				if err := stream.Receive(&req); err != nil {
					return err
				}
				return connect.NewError(connect.CodeFailedPrecondition, "nope")
			},
		},
	)

	return connect.NewClient(connectinprocess.New(server), clientInterceptors...), rec
}

func callUnary(ctx context.Context, client *connect.Client, spec connect.Spec) error {
	return client.CallUnary(ctx, spec, &emptypb.Empty{}, &emptypb.Empty{})
}

func drainStream(t *testing.T, ctx context.Context, client *connect.Client) int {
	t.Helper()

	stream, err := client.CallServerStream(ctx, streamSpec, &emptypb.Empty{})
	if err != nil {
		t.Fatalf("CallServerStream: %v", err)
	}
	defer func() { _ = stream.Close() }()

	received := 0
	for {
		var msg wrapperspb.StringValue
		err := stream.Receive(&msg)
		if errors.Is(err, io.EOF) {
			return received
		}
		if err != nil {
			t.Fatalf("Receive: %v", err)
		}
		received++
	}
}

type tenancy struct{ tenant, partition, access string }

func (t tenancy) GetTenantID() string    { return t.tenant }
func (t tenancy) GetPartitionID() string { return t.partition }
func (t tenancy) GetAccessID() string    { return t.access }

type failingTokenSource struct{}

func (failingTokenSource) Token() (*oauth2.Token, error) {
	return nil, errors.New("token endpoint down")
}

func TestAuthInterceptorSetsAPIKeyOnUnaryAndStreaming(t *testing.T) {
	client, rec := newTestClient(t, nil, interceptors.NewAuthInterceptor(interceptors.WithAPIKey("key-1")))
	ctx := context.Background()

	if err := callUnary(ctx, client, unarySpec); err != nil {
		t.Fatalf("unary: %v", err)
	}
	if got := rec.get("Authorization"); got != "Bearer key-1" {
		t.Fatalf("unary Authorization = %q", got)
	}

	if got := drainStream(t, ctx, client); got != streamMessages {
		t.Fatalf("received %d stream messages, want %d", got, streamMessages)
	}
	if got := rec.get("Authorization"); got != "Bearer key-1" {
		t.Fatalf("stream Authorization = %q", got)
	}
}

func TestAuthInterceptorPrefersTokenSource(t *testing.T) {
	ts := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "jwt-1"})
	client, rec := newTestClient(t, nil,
		interceptors.NewAuthInterceptor(interceptors.WithAPIKey("key-1"), interceptors.WithTokenSource(ts)))

	if err := callUnary(context.Background(), client, unarySpec); err != nil {
		t.Fatalf("unary: %v", err)
	}
	if got := rec.get("Authorization"); got != "Bearer jwt-1" {
		t.Fatalf("Authorization = %q, want the token-source token", got)
	}
}

func TestAuthInterceptorTokenFailureIsUnauthenticated(t *testing.T) {
	client, rec := newTestClient(t, nil,
		interceptors.NewAuthInterceptor(interceptors.WithTokenSource(failingTokenSource{})))

	err := callUnary(context.Background(), client, unarySpec)
	if got := connect.CodeOf(err); got != connect.CodeUnauthenticated {
		t.Fatalf("code = %v, want unauthenticated (err %v)", got, err)
	}
	if rec.count() != 0 {
		t.Fatal("the RPC must not reach the server without a token")
	}
}

func TestAuthInterceptorWithoutCredentialsSendsNoHeader(t *testing.T) {
	client, rec := newTestClient(t, nil, interceptors.NewAuthInterceptor())

	if err := callUnary(context.Background(), client, unarySpec); err != nil {
		t.Fatalf("unary: %v", err)
	}
	if got := rec.get("Authorization"); got != "" {
		t.Fatalf("Authorization = %q, want none", got)
	}
}

func TestPartitionInfoInterceptorSetsClientAndTenancyHeaders(t *testing.T) {
	client, rec := newTestClient(t, nil, interceptors.NewPartitionInfoInterceptor("gl-go/1.26.9"))
	ctx := util.SetTenancy(context.Background(), tenancy{tenant: "t1", partition: "p1", access: "a1"})

	if err := callUnary(ctx, client, unarySpec); err != nil {
		t.Fatalf("unary: %v", err)
	}
	want := map[string]string{
		"X-Ai-Api-Client": "gl-go/1.26.9",
		"X-Tenant-Id":     "t1",
		"X-Partition-Id":  "p1",
		"X-Access-Id":     "a1",
	}
	for name, value := range want {
		if got := rec.get(name); got != value {
			t.Fatalf("%s = %q, want %q", name, got, value)
		}
	}

	if got := drainStream(t, context.Background(), client); got != streamMessages {
		t.Fatalf("received %d stream messages, want %d", got, streamMessages)
	}
	if got := rec.get("X-Tenant-Id"); got != "" {
		t.Fatalf("X-Tenant-Id = %q without tenancy in ctx, want none", got)
	}
	if got := rec.get("X-Ai-Api-Client"); got != "gl-go/1.26.9" {
		t.Fatalf("stream X-Ai-Api-Client = %q", got)
	}
}

func TestLoggingInterceptorsPassCallsThrough(t *testing.T) {
	ctx := context.Background()
	opts := []interceptors.LoggingInterceptorOption{
		interceptors.WithLogRequests(true),
		interceptors.WithLogResponses(true),
		interceptors.WithLogHeaders(true),
	}
	client, _ := newTestClient(t,
		[]connect.ServerInterceptor{interceptors.NewLoggingServerInterceptor(ctx, opts...)},
		interceptors.NewLoggingClientInterceptor(ctx, opts...),
	)

	if err := callUnary(ctx, client, unarySpec); err != nil {
		t.Fatalf("unary: %v", err)
	}
	if got := drainStream(t, ctx, client); got != streamMessages {
		t.Fatalf("received %d stream messages, want %d", got, streamMessages)
	}

	err := callUnary(ctx, client, failSpec)
	if got := connect.CodeOf(err); got != connect.CodeFailedPrecondition {
		t.Fatalf("code = %v, want failed_precondition (err %v)", got, err)
	}
}
