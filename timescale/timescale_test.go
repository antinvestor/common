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

package timescale_test

import (
	"strings"
	"testing"
	"time"

	"github.com/antinvestor/common/timescale"
)

func TestRenderCreateHypertable_IncludesTimeColumnAndChunk(t *testing.T) {
	got := timescale.RenderCreateHypertable(timescale.Hypertable{
		Table:         "login_events",
		TimeColumn:    "created_at",
		ChunkInterval: 7 * 24 * time.Hour,
	})
	want := "SELECT create_hypertable('login_events', 'created_at', chunk_time_interval => INTERVAL '604800 seconds', if_not_exists => TRUE, create_default_indexes => FALSE);"
	if got != want {
		t.Fatalf("mismatch:\n  got: %s\n want: %s", got, want)
	}
}

func TestRenderCompression_WithSegmentBy_TwoStatements(t *testing.T) {
	sqls := timescale.RenderCompression(timescale.Hypertable{
		Table:         "login_events",
		TimeColumn:    "created_at",
		SegmentBy:     []string{"partition_id", "client_id"},
		CompressAfter: 14 * 24 * time.Hour,
	})
	if len(sqls) != 2 {
		t.Fatalf("expected 2 statements, got %d", len(sqls))
	}
	if !strings.Contains(sqls[0], "timescaledb.compress_segmentby = 'partition_id, client_id'") {
		t.Fatalf("missing segmentby clause: %s", sqls[0])
	}
	if !strings.Contains(sqls[0], "timescaledb.compress_orderby = 'created_at DESC'") {
		t.Fatalf("missing orderby clause: %s", sqls[0])
	}
	if !strings.Contains(sqls[1], "add_compression_policy('login_events'") {
		t.Fatalf("missing compression policy call: %s", sqls[1])
	}
}

func TestRenderCompression_NoSegmentBy_StillWorks(t *testing.T) {
	sqls := timescale.RenderCompression(timescale.Hypertable{
		Table:         "t",
		TimeColumn:    "created_at",
		CompressAfter: 24 * time.Hour,
	})
	if len(sqls) != 2 {
		t.Fatalf("expected 2 statements, got %d", len(sqls))
	}
	if strings.Contains(sqls[0], "segmentby") {
		t.Fatalf("should not include segmentby clause: %s", sqls[0])
	}
}

func TestRenderCompression_ZeroCompressAfter_Empty(t *testing.T) {
	if got := timescale.RenderCompression(timescale.Hypertable{Table: "t", TimeColumn: "created_at"}); len(got) != 0 {
		t.Fatalf("expected empty for zero CompressAfter, got %v", got)
	}
}

func TestRenderRetention_Zero_Empty(t *testing.T) {
	if got := timescale.RenderRetention(timescale.Hypertable{Table: "event_log", TimeColumn: "created_at"}); len(got) != 0 {
		t.Fatalf("expected no statements for zero retention, got %v", got)
	}
}

func TestRenderRetention_NonZero_OneStatement(t *testing.T) {
	sqls := timescale.RenderRetention(timescale.Hypertable{Table: "event_log", TimeColumn: "created_at", RetainFor: 30 * 24 * time.Hour})
	if len(sqls) != 1 {
		t.Fatalf("expected 1 statement, got %v", sqls)
	}
	if !strings.Contains(sqls[0], "add_retention_policy('event_log'") {
		t.Fatalf("missing retention policy call: %s", sqls[0])
	}
}

func TestValidate_RejectsMissingFields(t *testing.T) {
	cases := []timescale.Hypertable{
		{TimeColumn: "created_at", ChunkInterval: time.Hour},
		{Table: "t", ChunkInterval: time.Hour},
		{Table: "t", TimeColumn: "created_at"},
		{Table: "t", TimeColumn: "created_at", ChunkInterval: 0},
	}
	for _, c := range cases {
		if err := timescale.Validate(c); err == nil {
			t.Fatalf("expected validation error for %+v", c)
		}
	}
}

func TestValidate_AcceptsWellFormed(t *testing.T) {
	if err := timescale.Validate(timescale.Hypertable{Table: "t", TimeColumn: "created_at", ChunkInterval: time.Hour}); err != nil {
		t.Fatalf("unexpected: %v", err)
	}
}
