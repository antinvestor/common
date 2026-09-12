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
	"fmt"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"connectrpc.com/connect"
	"github.com/pitabwire/util"
)

// ManifestOption tunes a manifest built by NewManifest.
type ManifestOption func(*auditv1.AuditManifest)

// OpenVocabulary accepts any (action, resource_type) pair.
func OpenVocabulary() ManifestOption {
	return func(m *auditv1.AuditManifest) { m.SetOpenVocabulary(true) }
}

// AllowBackdating permits occurred_at older than the standard window, for
// producers that replay from an outbox.
func AllowBackdating() ManifestOption {
	return func(m *auditv1.AuditManifest) { m.SetAllowBackdating(true) }
}

// ExtraForbiddenKeys adds detail keys the audit service must reject.
func ExtraForbiddenKeys(keys ...string) ManifestOption {
	return func(m *auditv1.AuditManifest) { m.SetExtraForbiddenKeys(append(m.GetExtraForbiddenKeys(), keys...)) }
}

// NewManifest builds the registration request from the constants a
// producer uses (see constants.go), so the vocabulary lives in one place:
//
//	req := audit.NewManifest("service_loans",
//	    []string{audit.ActionCreate, audit.ActionApprove},
//	    []string{audit.ResourceLoanAccount, audit.ResourceRepayment})
func NewManifest(service string, actions, resourceTypes []string, opts ...ManifestOption) *auditv1.RegisterAuditManifestRequest {
	m := &auditv1.AuditManifest{}
	m.SetService(service)
	m.SetActions(actions)
	m.SetResourceTypes(resourceTypes)
	for _, opt := range opts {
		opt(m)
	}
	req := &auditv1.RegisterAuditManifestRequest{}
	req.SetManifest(m)
	return req
}

// RegisterManifest publishes the manifest. Call it from the producer's
// setup Job next to permission registration; an unchanged manifest is a
// no-op on the audit side.
func RegisterManifest(ctx context.Context, client auditv1connect.AuditServiceClient, req *auditv1.RegisterAuditManifestRequest) error {
	resp, err := client.RegisterAuditManifest(ctx, connect.NewRequest(req))
	if err != nil {
		return fmt.Errorf("register audit manifest for %q: %w", req.GetManifest().GetService(), err)
	}
	util.Log(ctx).WithField("service", resp.Msg.GetService()).WithField("version", resp.Msg.GetVersion()).
		WithField("unchanged", resp.Msg.GetUnchanged()).Info("audit manifest registered")
	return nil
}
