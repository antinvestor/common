// Copyright 2023-2026 Ant Investor Ltd.
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

package timescale

import (
	"reflect"
	"testing"
)

func TestRenderRLSMigrationStatements_RestoresOriginalState(t *testing.T) {
	state := rlsState{Enabled: true, Forced: true}

	disable := renderDisableRLS("public.login_events", state)
	wantDisable := []string{
		`ALTER TABLE "public"."login_events" NO FORCE ROW LEVEL SECURITY;`,
		`ALTER TABLE "public"."login_events" DISABLE ROW LEVEL SECURITY;`,
	}
	if !reflect.DeepEqual(disable, wantDisable) {
		t.Fatalf("disable mismatch:\n  got: %#v\n want: %#v", disable, wantDisable)
	}

	restore := renderRestoreRLS("public.login_events", state)
	wantRestore := []string{
		`ALTER TABLE "public"."login_events" ENABLE ROW LEVEL SECURITY;`,
		`ALTER TABLE "public"."login_events" FORCE ROW LEVEL SECURITY;`,
	}
	if !reflect.DeepEqual(restore, wantRestore) {
		t.Fatalf("restore mismatch:\n  got: %#v\n want: %#v", restore, wantRestore)
	}
}

func TestRenderRLSMigrationStatements_NoOpWhenRLSWasDisabled(t *testing.T) {
	state := rlsState{}
	if got := renderDisableRLS("login_events", state); len(got) != 0 {
		t.Fatalf("expected no disable statements, got %#v", got)
	}
	if got := renderRestoreRLS("login_events", state); len(got) != 0 {
		t.Fatalf("expected no restore statements, got %#v", got)
	}
}

func TestQuoteTableIdentifier_EscapesParts(t *testing.T) {
	got := quoteTableIdentifier(`odd"schema.login"events`)
	want := `"odd""schema"."login""events"`
	if got != want {
		t.Fatalf("quote mismatch:\n  got: %s\n want: %s", got, want)
	}
}
