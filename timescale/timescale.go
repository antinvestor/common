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

// Package timescale manages TimescaleDB hypertable lifecycle for services:
// extension check, hypertable creation, compression policy, retention policy.
// Callers declare their hypertables as configuration; Ensure applies the
// configuration idempotently.
package timescale

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/pitabwire/util"
	"gorm.io/gorm"
)

// Hypertable declares a table's hypertable configuration.
type Hypertable struct {
	// Table is the unqualified table name (e.g. "login_events").
	Table string
	// TimeColumn is the column the hypertable is partitioned by.
	TimeColumn string
	// ChunkInterval is the width of a single chunk.
	ChunkInterval time.Duration
	// SegmentBy is the columns used as compression segments. When set,
	// compressed chunks are segmented by these columns — queries filtering
	// on them can read only the relevant segments. Omit for tables whose
	// dominant filter is the time column alone.
	SegmentBy []string
	// CompressAfter enables compression for chunks older than this.
	// Zero = no compression policy.
	CompressAfter time.Duration
	// RetainFor enables a retention policy dropping chunks older than this.
	// Zero = keep all chunks forever (only compression reduces size).
	RetainFor time.Duration
}

// Validate returns nil if h is a complete, well-formed configuration.
func Validate(h Hypertable) error {
	if h.Table == "" {
		return errors.New("table is required")
	}
	if h.TimeColumn == "" {
		return errors.New("TimeColumn is required")
	}
	if h.ChunkInterval <= 0 {
		return errors.New("ChunkInterval must be positive")
	}
	return nil
}

// RenderCreateHypertable returns the SQL that converts a plain table into a
// hypertable. Idempotent via if_not_exists => TRUE. migrate_data => TRUE is
// required when an existing plain table already contains rows.
func RenderCreateHypertable(h Hypertable) string {
	return fmt.Sprintf(
		"SELECT create_hypertable('%s', '%s', chunk_time_interval => INTERVAL '%d seconds', if_not_exists => TRUE, migrate_data => TRUE, create_default_indexes => FALSE);",
		h.Table, h.TimeColumn, int(h.ChunkInterval.Seconds()),
	)
}

// RenderCompression returns the SQL statements to enable chunk compression
// and add the compression policy. Empty slice if CompressAfter is zero.
func RenderCompression(h Hypertable) []string {
	if h.CompressAfter <= 0 {
		return nil
	}
	var segmentBy string
	if len(h.SegmentBy) > 0 {
		segmentBy = fmt.Sprintf(", timescaledb.compress_segmentby = '%s'", strings.Join(h.SegmentBy, ", "))
	}
	return []string{
		fmt.Sprintf(
			"ALTER TABLE %s SET (timescaledb.compress, timescaledb.compress_orderby = '%s DESC'%s);",
			h.Table, h.TimeColumn, segmentBy,
		),
		fmt.Sprintf(
			"SELECT add_compression_policy('%s', INTERVAL '%d seconds', if_not_exists => TRUE);",
			h.Table, int(h.CompressAfter.Seconds()),
		),
	}
}

// RenderRetention returns the SQL adding a retention policy. Empty slice
// if RetainFor is zero.
func RenderRetention(h Hypertable) []string {
	if h.RetainFor <= 0 {
		return nil
	}
	return []string{
		fmt.Sprintf(
			"SELECT add_retention_policy('%s', INTERVAL '%d seconds', if_not_exists => TRUE);",
			h.Table, int(h.RetainFor.Seconds()),
		),
	}
}

// extensionLoaded reports whether the timescaledb extension is installed in
// the currently-connected database.
func extensionLoaded(ctx context.Context, db *gorm.DB) (bool, error) {
	var present int
	err := db.WithContext(ctx).
		Raw("SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb'").
		Scan(&present).Error
	if err != nil {
		return false, err
	}
	return present > 0, nil
}

// Ensure runs the full hypertable lifecycle for every entry in tables:
// conversion, compression, retention. Idempotent — safe to call on every
// service start.
//
// If the timescaledb extension is not loaded in the target database, Ensure
// logs a WARN and returns nil. This makes local dev / CI on a stock Postgres
// image painless — the service runs, tables stay plain, writes succeed.
//
// Any conversion or policy error is returned as a hard failure; services
// treat that as fatal at startup so a misconfigured DB refuses to run
// rather than silently operating without compression/retention.
func Ensure(ctx context.Context, db *gorm.DB, tables []Hypertable) error {
	log := util.Log(ctx)

	ok, err := extensionLoaded(ctx, db)
	if err != nil {
		return fmt.Errorf("check timescaledb extension: %w", err)
	}
	if !ok {
		log.Warn("timescaledb extension not loaded — hypertable conversion skipped")
		return nil
	}

	for _, h := range tables {
		if err := Validate(h); err != nil {
			return fmt.Errorf("hypertable %q invalid: %w", h.Table, err)
		}
		tlog := log.WithField("table", h.Table)

		if err := db.WithContext(ctx).Exec(RenderCreateHypertable(h)).Error; err != nil {
			return fmt.Errorf("create hypertable %s: %w", h.Table, err)
		}
		for _, sql := range RenderCompression(h) {
			if err := db.WithContext(ctx).Exec(sql).Error; err != nil {
				return fmt.Errorf("compression for %s: %w", h.Table, err)
			}
		}
		for _, sql := range RenderRetention(h) {
			if err := db.WithContext(ctx).Exec(sql).Error; err != nil {
				return fmt.Errorf("retention for %s: %w", h.Table, err)
			}
		}
		tlog.Info("hypertable ensured")
	}
	return nil
}
