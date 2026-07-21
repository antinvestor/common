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
	"sync"
	"time"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"connectrpc.com/connect"
	"github.com/pitabwire/frame/v2/security"
	"github.com/pitabwire/util"
)

// AuditBatchClient is the subset of AuditServiceClient used by Batcher.
// Full AuditServiceClient satisfies this interface.
type AuditBatchClient interface {
	CreateAuditEntry(context.Context, *connect.Request[auditv1.CreateAuditEntryRequest]) (*connect.Response[auditv1.CreateAuditEntryResponse], error)
	BatchCreateAuditEntries(context.Context, *connect.Request[auditv1.BatchCreateAuditEntriesRequest]) (*connect.Response[auditv1.BatchCreateAuditEntriesResponse], error)
}

// Compile-time check: generated client implements AuditBatchClient.
var _ AuditBatchClient = (auditv1connect.AuditServiceClient)(nil)

// Default batcher tunables. Sized for high write fan-in without delaying
// audit durability past a few hundred milliseconds under load.
const (
	defaultBatchMaxSize = 50
	defaultBatchMaxWait = 100 * time.Millisecond
	defaultBatchSendTO  = 10 * time.Second
)

// claimsCarrier is the subset of Frame claims needed to re-attach tenancy
// onto the outbound BatchCreate RPC context.
type claimsCarrier interface {
	GetTenantID() string
	GetPartitionID() string
	ClaimsToContext(ctx context.Context) context.Context
}

// pendingEntry is one audit row waiting to be flushed with its tenancy claims.
type pendingEntry struct {
	claims claimsCarrier
	req    *auditv1.CreateAuditEntryRequest
}

// Batcher coalesces many CreateAuditEntry calls into BatchCreateAuditEntries
// RPCs, grouped by tenant/partition so server-side hash chains stay coherent.
// It is safe for concurrent Enqueue; Flush drains all buckets.
type Batcher struct {
	client  AuditBatchClient
	maxSize int
	maxWait time.Duration
	sendTO  time.Duration

	mu      sync.Mutex
	buckets map[string]*batchBucket
	closed  bool
	wg      sync.WaitGroup
}

type batchBucket struct {
	key     string
	entries []pendingEntry
	timer   *time.Timer
}

// BatcherOption configures a Batcher.
type BatcherOption func(*Batcher)

// WithBatchMaxSize sets how many entries to accumulate before an eager flush.
func WithBatchMaxSize(n int) BatcherOption {
	return func(b *Batcher) {
		if n > 0 {
			b.maxSize = n
		}
	}
}

// WithBatchMaxWait sets the maximum time an entry may wait before flush.
func WithBatchMaxWait(d time.Duration) BatcherOption {
	return func(b *Batcher) {
		if d > 0 {
			b.maxWait = d
		}
	}
}

// WithBatchSendTimeout sets the RPC timeout used when flushing a batch.
func WithBatchSendTimeout(d time.Duration) BatcherOption {
	return func(b *Batcher) {
		if d > 0 {
			b.sendTO = d
		}
	}
}

// NewBatcher creates a batching front-end for the audit service client.
// A nil client is allowed (Enqueue becomes a no-op) for local/dev setups.
func NewBatcher(client AuditBatchClient, opts ...BatcherOption) *Batcher {
	b := &Batcher{
		client:  client,
		maxSize: defaultBatchMaxSize,
		maxWait: defaultBatchMaxWait,
		sendTO:  defaultBatchSendTO,
		buckets: make(map[string]*batchBucket),
	}
	for _, opt := range opts {
		opt(b)
	}
	return b
}

// Enqueue schedules an audit entry for batch insert. Safe for concurrent use.
// claims may be nil (tenant-less entries share one bucket).
func (b *Batcher) Enqueue(claims claimsCarrier, req *auditv1.CreateAuditEntryRequest) {
	if b == nil || b.client == nil || req == nil {
		return
	}

	b.mu.Lock()
	defer b.mu.Unlock()
	if b.closed {
		return
	}

	key := bucketKey(claims)
	bk, ok := b.buckets[key]
	if !ok {
		bk = &batchBucket{key: key}
		b.buckets[key] = bk
		bk.timer = time.AfterFunc(b.maxWait, func() {
			b.flushKey(key)
		})
	}
	bk.entries = append(bk.entries, pendingEntry{claims: claims, req: req})

	if len(bk.entries) >= b.maxSize {
		if bk.timer != nil {
			bk.timer.Stop()
			bk.timer = nil
		}
		entries := bk.entries
		delete(b.buckets, key)
		b.spawnSend(entries)
	}
}

// Flush sends all pending entries immediately and waits for in-flight RPCs.
func (b *Batcher) Flush() {
	if b == nil {
		return
	}
	b.mu.Lock()
	pending := make([][]pendingEntry, 0, len(b.buckets))
	for key, bk := range b.buckets {
		if bk.timer != nil {
			bk.timer.Stop()
		}
		if len(bk.entries) > 0 {
			pending = append(pending, bk.entries)
		}
		delete(b.buckets, key)
	}
	b.mu.Unlock()

	for _, entries := range pending {
		b.spawnSend(entries)
	}
	b.wg.Wait()
}

// Close stops accepting new entries, flushes, and waits for completion.
func (b *Batcher) Close() {
	if b == nil {
		return
	}
	b.mu.Lock()
	b.closed = true
	b.mu.Unlock()
	b.Flush()
}

func (b *Batcher) flushKey(key string) {
	b.mu.Lock()
	bk, ok := b.buckets[key]
	if !ok {
		b.mu.Unlock()
		return
	}
	if bk.timer != nil {
		bk.timer.Stop()
	}
	entries := bk.entries
	delete(b.buckets, key)
	b.mu.Unlock()

	if len(entries) == 0 {
		return
	}
	b.spawnSend(entries)
}

func (b *Batcher) spawnSend(entries []pendingEntry) {
	b.wg.Add(1)
	go func() {
		defer b.wg.Done()
		b.sendBatch(entries)
	}()
}

func (b *Batcher) sendBatch(entries []pendingEntry) {
	if len(entries) == 0 || b.client == nil {
		return
	}

	// Single-entry path uses CreateAuditEntry (same as legacy) to avoid
	// paying batch RPC overhead for solitary flushes.
	if len(entries) == 1 {
		b.sendOne(entries[0])
		return
	}

	sendCtx, cancel := context.WithTimeout(context.Background(), b.sendTO)
	defer cancel()

	// All entries in a bucket share tenant/partition; re-attach claims from
	// the first item so the server assigns the correct chain tip.
	if entries[0].claims != nil {
		sendCtx = entries[0].claims.ClaimsToContext(sendCtx)
	}

	reqs := make([]*auditv1.CreateAuditEntryRequest, 0, len(entries))
	for _, e := range entries {
		reqs = append(reqs, e.req)
	}

	_, err := b.client.BatchCreateAuditEntries(sendCtx, connect.NewRequest(&auditv1.BatchCreateAuditEntriesRequest{
		Entries: reqs,
	}))
	if err != nil {
		util.Log(sendCtx).WithError(err).WithField("batch_size", len(reqs)).
			Warn("audit batch create failed; falling back to single inserts")
		for _, e := range entries {
			b.sendOne(e)
		}
	}
}

func (b *Batcher) sendOne(e pendingEntry) {
	if e.req == nil || b.client == nil {
		return
	}
	sendCtx, cancel := context.WithTimeout(context.Background(), b.sendTO)
	defer cancel()
	if e.claims != nil {
		sendCtx = e.claims.ClaimsToContext(sendCtx)
	}
	_, _ = b.client.CreateAuditEntry(sendCtx, connect.NewRequest(e.req))
}

func bucketKey(claims claimsCarrier) string {
	if claims == nil {
		return "|"
	}
	return claims.GetTenantID() + "|" + claims.GetPartitionID()
}

// claimsFromContext extracts a claimsCarrier for batch tenancy grouping.
func claimsFromContext(ctx context.Context) claimsCarrier {
	claims := security.ClaimsFromContext(ctx)
	if claims == nil {
		return nil
	}
	return claims
}
