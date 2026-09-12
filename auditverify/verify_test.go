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

package auditverify_test

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"github.com/antinvestor/common/auditverify"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/structpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// fixtureEntry mirrors the fixture in
// service-authentication/apps/audit/service/business/canon_test.go so the
// shared golden vector proves both encoders agree.
func fixtureEntry(t *testing.T) *auditv1.AuditEntryObject {
	t.Helper()
	at := time.Date(2026, 9, 12, 10, 30, 0, 123456789, time.UTC)
	details, err := structpb.NewStruct(map[string]any{
		"z": 1, "a": "b|c", "nested": map[string]any{"y": true, "x": []any{1.5, "ü"}},
	})
	require.NoError(t, err)
	rel := &auditv1.AuditRelation{}
	rel.SetParentType("profile")
	rel.SetParentId("p1")
	rel.SetChildType("contact")
	rel.SetChildId("c1")
	rel.SetAction("added")

	e := &auditv1.AuditEntryObject{}
	e.SetTenantId("tenant")
	e.SetPartitionId("part")
	e.SetProfileId("prof|1")
	e.SetAction("create")
	e.SetResourceType("loan")
	e.SetResourceId("loan-1")
	e.SetService("service_loans")
	e.SetDetails(details)
	e.SetIpAddress("10.0.0.1")
	e.SetUserAgent("ua")
	e.SetDeviceId("dev")
	e.SetTargetProfileId("t")
	e.SetTraceId("tr")
	e.SetSeq(7)
	e.SetCanonVersion(auditverify.CanonVersionV2)
	e.SetEntryId("e-1")
	e.SetOnBehalfOf("obo")
	e.SetActorServiceAccountId("sa")
	e.SetOccurredAt(timestamppb.New(at))
	e.SetReceivedAt(timestamppb.New(at.Add(time.Second)))
	e.SetCreatedAt(timestamppb.New(at.Add(2 * time.Second)))
	e.SetIntentId("intent")
	e.SetPayloadHash("ab")
	e.SetRelations([]*auditv1.AuditRelation{rel})
	return e
}

func TestCanonical_MatchesServiceGoldenVector(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("testdata", "canon_v2", "fixture.json"))
	require.NoError(t, err)
	var golden struct {
		CanonHex  string `json:"canon_hex"`
		CanonSHA  string `json:"canon_sha256"`
		EntryHash string `json:"entry_hash_genesis"`
	}
	require.NoError(t, json.Unmarshal(raw, &golden))

	e := fixtureEntry(t)
	canon := auditverify.Canonical(e)
	sum := sha256.Sum256(canon)
	require.Equal(t, golden.CanonHex, hex.EncodeToString(canon))
	require.Equal(t, golden.CanonSHA, hex.EncodeToString(sum[:]))
	require.Equal(t, golden.EntryHash, auditverify.EntryHashV2(e, ""))
}

// chainBuilder signs a chain the way the audit service does.
type chainBuilder struct {
	pub  ed25519.PublicKey
	priv ed25519.PrivateKey
	prev string
	seq  int64
}

func newChain(t *testing.T) *chainBuilder {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	return &chainBuilder{pub: pub, priv: priv}
}

func (c *chainBuilder) entry(t *testing.T, action string) *auditv1.AuditEntryObject {
	t.Helper()
	c.seq++
	e := &auditv1.AuditEntryObject{}
	e.SetTenantId("tenant")
	e.SetSeq(c.seq)
	e.SetCanonVersion(auditverify.CanonVersionV2)
	e.SetProfileId("person")
	e.SetAction(action)
	e.SetResourceType("thing")
	e.SetService("svc")
	e.SetKeyId("k1")
	e.SetCreatedAt(timestamppb.New(time.Date(2026, 9, 12, 12, 0, int(c.seq), 0, time.UTC)))
	e.SetPreviousHash(c.prev)
	e.SetEntryHash(auditverify.EntryHashV2(e, c.prev))
	raw, err := hex.DecodeString(e.GetEntryHash())
	require.NoError(t, err)
	e.SetSignature(hex.EncodeToString(ed25519.Sign(c.priv, raw)))
	c.prev = e.GetEntryHash()
	return e
}

func (c *chainBuilder) checkpoint(t *testing.T, seq int64, hash string) *auditv1.AuditCheckpoint {
	t.Helper()
	cp := &auditv1.AuditCheckpoint{}
	cp.SetTenantId("tenant")
	cp.SetSeq(seq)
	cp.SetEntryHash(hash)
	cp.SetKeyId("k1")
	cp.SetCreatedAt(timestamppb.New(time.Date(2026, 9, 12, 13, 0, 0, 0, time.UTC)))
	raw, err := hex.DecodeString(auditverify.CheckpointHash(cp))
	require.NoError(t, err)
	cp.SetSignature(hex.EncodeToString(ed25519.Sign(c.priv, raw)))
	return cp
}

func (c *chainBuilder) key() *auditv1.SigningKey {
	k := &auditv1.SigningKey{}
	k.SetKeyId("k1")
	k.SetAlgorithm("ed25519")
	k.SetPublicKey(hex.EncodeToString(c.pub))
	return k
}

func header(start, end int64, startCP, endCP *auditv1.AuditCheckpoint, key *auditv1.SigningKey) *auditv1.ExportAuditEntriesResponse {
	h := &auditv1.ExportAuditEntriesResponse_Header{}
	h.SetTenantId("tenant")
	h.SetStartSeq(start)
	h.SetEndSeq(end)
	if startCP != nil {
		h.SetStartCheckpoint(startCP)
	}
	if endCP != nil {
		h.SetEndCheckpoint(endCP)
	}
	h.SetKeys([]*auditv1.SigningKey{key})
	m := &auditv1.ExportAuditEntriesResponse{}
	m.SetHeader(h)
	return m
}

func entryMsg(e *auditv1.AuditEntryObject) *auditv1.ExportAuditEntriesResponse {
	m := &auditv1.ExportAuditEntriesResponse{}
	m.SetEntry(e)
	return m
}

func TestVerify_BundleFromGenesisAndFromCheckpoint(t *testing.T) {
	c := newChain(t)
	entries := make([]*auditv1.AuditEntryObject, 0, 10)
	for i := range 10 {
		entries = append(entries, c.entry(t, "act-"+string(rune('a'+i))))
	}
	cp5 := c.checkpoint(t, 5, entries[4].GetEntryHash())
	cp10 := c.checkpoint(t, 10, entries[9].GetEntryHash())

	// From genesis with the header's keys.
	msgs := []*auditv1.ExportAuditEntriesResponse{header(1, 10, nil, cp10, c.key())}
	for _, e := range entries {
		msgs = append(msgs, entryMsg(e))
	}
	rep, err := auditverify.Verify(msgs, auditverify.Options{TrustHeaderKeys: true})
	require.NoError(t, err)
	require.True(t, rep.Valid, rep.Reason)
	require.Equal(t, int64(10), rep.EntriesVerified)
	require.Equal(t, int64(1), rep.CheckpointsVerified, "end checkpoint verified")
	require.Equal(t, entries[9].GetEntryHash(), rep.EndHash)
	require.Equal(t, []string{"k1"}, rep.KeyIDs)

	// Header keys are refused unless trusted or supplied out of band.
	_, err = auditverify.Verify(msgs, auditverify.Options{})
	require.ErrorIs(t, err, auditverify.ErrNoKeys)
	rep, err = auditverify.Verify(msgs, auditverify.Options{Keys: auditverify.KeySet{"k1": c.pub}})
	require.NoError(t, err)
	require.True(t, rep.Valid)

	// From checkpoint 5: entries 6..10.
	partial := []*auditv1.ExportAuditEntriesResponse{header(6, 10, cp5, cp10, c.key())}
	for _, e := range entries[5:] {
		partial = append(partial, entryMsg(e))
	}
	rep, err = auditverify.Verify(partial, auditverify.Options{TrustHeaderKeys: true})
	require.NoError(t, err)
	require.True(t, rep.Valid, rep.Reason)
	require.Equal(t, int64(5), rep.EntriesVerified)
	require.Equal(t, int64(2), rep.CheckpointsVerified)

	// A bundle that starts mid-chain without a checkpoint cannot be verified.
	_, err = auditverify.Verify(append([]*auditv1.ExportAuditEntriesResponse{header(6, 10, nil, nil, c.key())}, partial[1:]...),
		auditverify.Options{TrustHeaderKeys: true})
	require.Error(t, err)

	// File round trip.
	var buf bytes.Buffer
	require.NoError(t, auditverify.WriteBundle(&buf, msgs))
	rep, err = auditverify.VerifyBundle(&buf, auditverify.Options{TrustHeaderKeys: true})
	require.NoError(t, err)
	require.True(t, rep.Valid)
}

func TestVerify_DetectsEveryKindOfTampering(t *testing.T) {
	build := func(mutate func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse) *auditverify.Report {
		c := newChain(t)
		entries := make([]*auditv1.AuditEntryObject, 0, 4)
		for range 4 {
			entries = append(entries, c.entry(t, "create"))
		}
		msgs := mutate(entries, c)
		rep, err := auditverify.Verify(msgs, auditverify.Options{TrustHeaderKeys: true})
		require.NoError(t, err)
		return rep
	}
	all := func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse {
		msgs := []*auditv1.ExportAuditEntriesResponse{header(1, 4, nil, nil, c.key())}
		for _, e := range entries {
			msgs = append(msgs, entryMsg(e))
		}
		return msgs
	}

	rep := build(func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse {
		entries[2].SetAction("delete")
		return all(entries, c)
	})
	require.False(t, rep.Valid)
	require.Equal(t, int64(3), rep.FirstInvalidSeq)
	require.Contains(t, rep.Reason, "entry_hash")

	rep = build(func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse {
		return all(append(entries[:1], entries[2:]...), c)
	})
	require.False(t, rep.Valid)
	require.Equal(t, int64(3), rep.FirstInvalidSeq)
	require.Contains(t, rep.Reason, "gap")

	rep = build(func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse {
		other := newChain(t)
		msgs := all(entries, c)
		msgs[0].GetHeader().SetKeys([]*auditv1.SigningKey{other.key()})
		return msgs
	})
	require.False(t, rep.Valid)
	require.Equal(t, int64(1), rep.FirstInvalidSeq)
	require.Contains(t, rep.Reason, "signature")

	rep = build(func(entries []*auditv1.AuditEntryObject, c *chainBuilder) []*auditv1.ExportAuditEntriesResponse {
		bad := c.checkpoint(t, 4, entries[3].GetEntryHash())
		bad.SetEntryHash(entries[2].GetEntryHash())
		return append([]*auditv1.ExportAuditEntriesResponse{header(1, 4, nil, bad, c.key())}, all(entries, c)[1:]...)
	})
	require.False(t, rep.Valid)
	require.Contains(t, rep.Reason, "end checkpoint")
}

func TestVerify_LegacyCanonVersionOne(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	e := &auditv1.AuditEntryObject{}
	e.SetTenantId("tenant")
	e.SetSeq(1)
	e.SetCanonVersion(auditverify.CanonVersionLegacy)
	e.SetProfileId("legacy")
	e.SetAction("login")
	e.SetResourceType("session")
	e.SetService("service_authentication")
	e.SetKeyId("k1")
	e.SetCreatedAt(timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)))
	e.SetEntryHash(auditverify.EntryHashV1(e, ""))
	e.SetSignature(hex.EncodeToString(ed25519.Sign(priv, []byte(e.GetEntryHash()))))
	k := &auditv1.SigningKey{}
	k.SetKeyId("k1")
	k.SetPublicKey(hex.EncodeToString(pub))
	rep, err := auditverify.Verify([]*auditv1.ExportAuditEntriesResponse{header(1, 1, nil, nil, k), entryMsg(e)},
		auditverify.Options{TrustHeaderKeys: true})
	require.NoError(t, err)
	require.True(t, rep.Valid, rep.Reason)
}
