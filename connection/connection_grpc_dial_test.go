// Copyright 2023-2026 Ant Investor Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package connection

import (
	"strings"
	"testing"
)

func TestGrpcTargetAndTransportHTTPS(t *testing.T) {
	target, opt, err := grpcTargetAndTransport("https://identity-authorization-keto-write-xxx.a.run.app")
	if err != nil {
		t.Fatal(err)
	}
	if target != "identity-authorization-keto-write-xxx.a.run.app" {
		t.Fatalf("target = %q", target)
	}
	if opt == nil {
		t.Fatal("expected TLS dial option")
	}
}

func TestGrpcTargetAndTransportHTTPSWithPort(t *testing.T) {
	target, _, err := grpcTargetAndTransport("https://authz-w.stawi.org:443")
	if err != nil {
		t.Fatal(err)
	}
	if target != "authz-w.stawi.org:443" {
		t.Fatalf("target = %q", target)
	}
}

func TestGrpcTargetAndTransportHTTPPlaintext(t *testing.T) {
	target, opt, err := grpcTargetAndTransport("http://keto-write:4467")
	if err != nil {
		t.Fatal(err)
	}
	if target != "keto-write:4467" {
		t.Fatalf("target = %q", target)
	}
	if opt == nil {
		t.Fatal("expected dial option")
	}
}

func TestGrpcTargetAndTransportBare443TLS(t *testing.T) {
	target, _, err := grpcTargetAndTransport("example.com:443")
	if err != nil {
		t.Fatal(err)
	}
	if target != "example.com:443" {
		t.Fatalf("target = %q", target)
	}
}

func TestGrpcTargetAndTransportBarePortPlaintext(t *testing.T) {
	target, _, err := grpcTargetAndTransport("keto-write:4467")
	if err != nil {
		t.Fatal(err)
	}
	if target != "keto-write:4467" {
		t.Fatalf("target = %q", target)
	}
}

func TestGrpcTargetAndTransportPublicDNSDefaultTLS(t *testing.T) {
	// Cloud Run / public host without port must use TLS (not insecure).
	target, _, err := grpcTargetAndTransport("service-xxx.a.run.app")
	if err != nil {
		t.Fatal(err)
	}
	if target != "service-xxx.a.run.app" {
		t.Fatalf("target = %q", target)
	}
}

func TestGrpcTargetAndTransportShortNamePlaintext(t *testing.T) {
	target, _, err := grpcTargetAndTransport("keto")
	if err != nil {
		t.Fatal(err)
	}
	if target != "keto" {
		t.Fatalf("target = %q", target)
	}
}

func TestGrpcTargetAndTransportEmpty(t *testing.T) {
	_, _, err := grpcTargetAndTransport("  ")
	if err == nil {
		t.Fatal("expected error for empty endpoint")
	}
	if !strings.Contains(err.Error(), "required") {
		t.Fatalf("unexpected error: %v", err)
	}
}
