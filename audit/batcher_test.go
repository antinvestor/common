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
	"sync/atomic"
	"testing"
	"time"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"connectrpc.com/connect"
	"github.com/stretchr/testify/require"
)

type stubBatchClient struct {
	batchCalls   atomic.Int32
	singleCalls  atomic.Int32
	lastBatchLen atomic.Int32
}

func (s *stubBatchClient) CreateAuditEntry(
	_ context.Context,
	_ *connect.Request[auditv1.CreateAuditEntryRequest],
) (*connect.Response[auditv1.CreateAuditEntryResponse], error) {
	s.singleCalls.Add(1)
	return connect.NewResponse(&auditv1.CreateAuditEntryResponse{}), nil
}

func (s *stubBatchClient) BatchCreateAuditEntries(
	_ context.Context,
	req *connect.Request[auditv1.BatchCreateAuditEntriesRequest],
) (*connect.Response[auditv1.BatchCreateAuditEntriesResponse], error) {
	s.batchCalls.Add(1)
	s.lastBatchLen.Store(int32(len(req.Msg.GetEntries())))
	return connect.NewResponse(&auditv1.BatchCreateAuditEntriesResponse{}), nil
}

func TestBatcherFlushesOnMaxSize(t *testing.T) {
	stub := &stubBatchClient{}
	// Long wait so only size triggers flush.
	b := NewBatcher(stub, WithBatchMaxSize(3), WithBatchMaxWait(time.Hour))

	for i := 0; i < 3; i++ {
		b.Enqueue(&testClaims{tenant: "t1", partition: "p1"}, &auditv1.CreateAuditEntryRequest{
			ProfileId: "prof",
			Action:    "test",
			Service:   "svc",
		})
	}

	require.Eventually(t, func() bool {
		return stub.batchCalls.Load() == 1
	}, 2*time.Second, 10*time.Millisecond)
	require.Equal(t, int32(3), stub.lastBatchLen.Load())
	require.Equal(t, int32(0), stub.singleCalls.Load())
}

func TestBatcherFlushesOnMaxWait(t *testing.T) {
	stub := &stubBatchClient{}
	b := NewBatcher(stub, WithBatchMaxSize(50), WithBatchMaxWait(30*time.Millisecond))

	b.Enqueue(&testClaims{tenant: "t1", partition: "p1"}, &auditv1.CreateAuditEntryRequest{
		ProfileId: "prof",
		Action:    "test",
		Service:   "svc",
	})
	b.Enqueue(&testClaims{tenant: "t1", partition: "p1"}, &auditv1.CreateAuditEntryRequest{
		ProfileId: "prof",
		Action:    "test2",
		Service:   "svc",
	})

	require.Eventually(t, func() bool {
		return stub.batchCalls.Load() == 1
	}, 2*time.Second, 10*time.Millisecond)
	require.Equal(t, int32(2), stub.lastBatchLen.Load())
}

func TestBatcherGroupsByTenant(t *testing.T) {
	stub := &stubBatchClient{}
	b := NewBatcher(stub, WithBatchMaxSize(10), WithBatchMaxWait(time.Hour))

	b.Enqueue(&testClaims{tenant: "t1", partition: "p1"}, &auditv1.CreateAuditEntryRequest{ProfileId: "a", Action: "x", Service: "s"})
	b.Enqueue(&testClaims{tenant: "t2", partition: "p2"}, &auditv1.CreateAuditEntryRequest{ProfileId: "b", Action: "y", Service: "s"})
	b.Enqueue(&testClaims{tenant: "t1", partition: "p1"}, &auditv1.CreateAuditEntryRequest{ProfileId: "c", Action: "z", Service: "s"})

	b.Flush()

	// t1 has 2 entries → 1 batch call; t2 has 1 → 1 single call.
	require.Equal(t, int32(1), stub.batchCalls.Load())
	require.Equal(t, int32(1), stub.singleCalls.Load())
	require.Equal(t, int32(2), stub.lastBatchLen.Load())
}

type testClaims struct {
	tenant, partition string
}

func (c *testClaims) GetTenantID() string    { return c.tenant }
func (c *testClaims) GetPartitionID() string { return c.partition }
func (c *testClaims) ClaimsToContext(ctx context.Context) context.Context {
	return ctx
}
