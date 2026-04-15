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
	"net/http"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	"connectrpc.com/connect"
)

// NewAuditClient creates a Connect RPC client for the audit service.
// The httpClient should include any authentication middleware.
func NewAuditClient(baseURL string, httpClient *http.Client) auditv1connect.AuditServiceClient {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	return auditv1connect.NewAuditServiceClient(httpClient, baseURL)
}

// NewConnectClient creates a Connect RPC audit service client.
// This signature matches the pattern expected by connection.NewServiceClient.
func NewConnectClient(httpClient connect.HTTPClient, baseURL string, opts ...connect.ClientOption) auditv1connect.AuditServiceClient {
	return auditv1connect.NewAuditServiceClient(httpClient, baseURL, opts...)
}
