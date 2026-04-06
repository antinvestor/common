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

package permissions

import (
	"strings"
	"time"

	commonv1 "buf.build/gen/go/antinvestor/common/protocolbuffers/go/common/v1"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
	"google.golang.org/protobuf/types/descriptorpb"
)

// PermissionManifest is the payload published by services at startup to
// register their permission namespace, available permissions, and
// role-to-permission mappings with the authorization service.
type PermissionManifest struct {
	Namespace    string              `json:"namespace"`
	Permissions  []string            `json:"permissions"`
	RoleBindings map[string][]string `json:"role_bindings"`
	RegisteredAt time.Time           `json:"registered_at"`
}

// ManifestRegistrationPath is the internal HTTP endpoint on the authorization
// service that accepts permission manifest registrations.
const ManifestRegistrationPath = "/_internal/register/permissions"

// ManifestRegistrationURLEnvVar is the environment variable that overrides the
// full URL for permission manifest registration.
const ManifestRegistrationURLEnvVar = "PERMISSIONS_REGISTRATION_URL"

// BuildManifest extracts a PermissionManifest from a proto service descriptor.
// It reads the service_permissions annotation to get namespace, permissions,
// and role bindings.
func BuildManifest(sd protoreflect.ServiceDescriptor) PermissionManifest {
	manifest := PermissionManifest{
		RegisteredAt: time.Now().UTC(),
		RoleBindings: make(map[string][]string),
	}

	opts, ok := sd.Options().(*descriptorpb.ServiceOptions)
	if !ok || opts == nil {
		return manifest
	}

	ext, ok := proto.GetExtension(opts, commonv1.E_ServicePermissions).(*commonv1.ServicePermissions)
	if !ok || ext == nil {
		return manifest
	}

	manifest.Namespace = ext.GetNamespace()
	manifest.Permissions = ext.GetPermissions()

	for _, rb := range ext.GetRoleBindings() {
		roleName := standardRoleToString(rb.GetRole())
		if roleName != "" {
			manifest.RoleBindings[roleName] = rb.GetPermissions()
		}
	}

	return manifest
}

// standardRoleToString converts a StandardRole enum to its lowercase string
// name used in Keto relations (owner, admin, operator, viewer, member, service).
func standardRoleToString(role commonv1.StandardRole) string {
	name := role.String()
	if name == "" || role == commonv1.StandardRole_ROLE_UNSPECIFIED {
		return ""
	}
	return strings.ToLower(strings.TrimPrefix(name, "ROLE_"))
}
