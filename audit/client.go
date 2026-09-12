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
	"context"
	"net/http"
	"time"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	"connectrpc.com/connect"
	common "github.com/antinvestor/common/v2"
	"github.com/antinvestor/common/v2/connection"
	"github.com/antinvestor/common/v2/connection/options"
)

// ClientTimeout bounds every call the interceptor makes. It is set once on
// the HTTP client; handlers never add per-call deadlines.
const ClientTimeout = 2 * time.Second

// NewAuditClient creates a Connect RPC client for the audit service.
// The httpClient should include any authentication middleware.
func NewAuditClient(baseURL string, httpClient *http.Client) auditv1connect.AuditServiceClient {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: ClientTimeout}
	}
	return auditv1connect.NewAuditServiceClient(httpClient, baseURL)
}

// NewConnectClient creates a Connect RPC audit service client.
// This signature matches the pattern expected by connection.NewServiceClient.
func NewConnectClient(httpClient connect.HTTPClient, baseURL string, opts ...connect.ClientOption) auditv1connect.AuditServiceClient {
	return auditv1connect.NewAuditServiceClient(httpClient, baseURL, opts...)
}

// ClientOptions returns the client options producers should pass to
// connection.NewServiceClient: an HTTP client with ClientTimeout. The
// OAuth interceptor is still applied by the connection package.
func ClientOptions(ctx context.Context) ([]common.ClientOption, error) {
	httpClient, err := connection.NewHTTPClient(ctx, options.WithHTTPTimeout(ClientTimeout))
	if err != nil {
		return nil, err
	}
	return []common.ClientOption{common.WithHTTPClient(httpClient)}, nil
}

// NewServiceClient resolves the audit service target from cfg and builds a
// client with the short interceptor timeout.
func NewServiceClient(ctx context.Context, cfg any, target common.ServiceTarget) (auditv1connect.AuditServiceClient, error) {
	opts, err := ClientOptions(ctx)
	if err != nil {
		return nil, err
	}
	return connection.NewServiceClient(ctx, cfg, target, NewConnectClient, opts...)
}
