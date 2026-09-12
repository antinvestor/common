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
	"strings"

	"github.com/pitabwire/frame/v2/security"
)

// Actor is the person an audit entry is attributed to.
type Actor struct {
	// ProfileID is the person who acted (or on whose behalf an operator acted).
	ProfileID string
	// OnBehalfOf is set when a service-account caller acts for a person; it
	// then equals ProfileID and the service account is recorded from claims.
	OnBehalfOf string
	// ServiceAccountID is the caller's service account, if any.
	ServiceAccountID string
	DeviceID         string
}

// ResolveActor applies the audit actor rule to the request context.
//
// The audit chain records human actions only:
//
//   - A user token (profile_id, no service_account_id) is a person: audited.
//   - A service-account token is a machine: NOT audited, unless the handler
//     called WithOnBehalfOf, in which case the entry is attributed to that
//     person and the service account is recorded alongside.
//   - Roles play no part. In particular the "internal" role, which the
//     platform grants to root administrators and owners, must never exempt
//     a person from being audited.
//
// ok is false when the call should produce no entry.
func ResolveActor(ctx context.Context) (Actor, bool) {
	claims := security.ClaimsFromContext(ctx)
	if claims == nil {
		return Actor{}, false
	}
	profileID := strings.TrimSpace(claims.GetProfileID())
	if profileID == "" {
		return Actor{}, false
	}
	actor := Actor{DeviceID: claims.GetDeviceID()}
	if v, ok := claims.Ext["service_account_id"].(string); ok {
		actor.ServiceAccountID = strings.TrimSpace(v)
	}
	if actor.ServiceAccountID == "" {
		actor.ProfileID = profileID
		return actor, true
	}
	obo := OnBehalfOfFromContext(ctx)
	if obo == "" {
		return Actor{}, false
	}
	actor.ProfileID = obo
	actor.OnBehalfOf = obo
	return actor, true
}

// OnBehalfOfFromContext returns the person set by WithOnBehalfOf, if any.
func OnBehalfOfFromContext(ctx context.Context) string {
	e := entryFromContext(ctx)
	if e == nil {
		return ""
	}
	return strings.TrimSpace(e.OnBehalfOf)
}
