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

package auditverify

import (
	"bufio"
	"crypto/ed25519"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
	"google.golang.org/protobuf/proto"
)

// KeySet maps key ids to public keys. Build it from the bundle header, from
// GET /.well-known/audit-keys.json, or from a pinned copy.
type KeySet map[string]ed25519.PublicKey

// KeySetFromProto converts published keys into a KeySet.
func KeySetFromProto(keys []*auditv1.SigningKey) (KeySet, error) {
	ks := KeySet{}
	for _, k := range keys {
		raw, err := hex.DecodeString(k.GetPublicKey())
		if err != nil || len(raw) != ed25519.PublicKeySize {
			return nil, fmt.Errorf("key %q: invalid public key", k.GetKeyId())
		}
		ks[k.GetKeyId()] = ed25519.PublicKey(raw)
	}
	return ks, nil
}

// Report is the outcome of verifying a bundle.
type Report struct {
	TenantID            string
	FirstSeq            int64
	LastSeq             int64
	EntriesVerified     int64
	CheckpointsVerified int64
	KeyIDs              []string
	// Valid is false when a break was found; FirstInvalidSeq and Reason say where.
	Valid           bool
	FirstInvalidSeq int64
	Reason          string
	// EndHash is the entry hash at LastSeq, for anchoring or continuation.
	EndHash string
}

// Options tune verification.
type Options struct {
	// Keys overrides the keys carried in the bundle header. Use it to verify
	// against keys obtained out of band (pinned or from the well-known URL)
	// so a forged bundle cannot supply its own keys.
	Keys KeySet
	// TrustHeaderKeys allows the bundle's own keys when Keys is nil.
	TrustHeaderKeys bool
}

// ErrNoKeys is returned when neither Options.Keys nor trusted header keys exist.
var ErrNoKeys = errors.New("auditverify: no verification keys available")

// Verify checks a bundle given as the ordered export messages.
//
// The walk starts at the header's start checkpoint (whose signature is
// checked) or at genesis when the bundle begins at seq 1. Every entry must
// have the expected seq, link to the previous hash, re-hash under its
// canon_version and verify under its key_id. When the header carries an end
// checkpoint at the last seq, its hash must match too.
func Verify(msgs []*auditv1.ExportAuditEntriesResponse, opts Options) (*Report, error) {
	if len(msgs) == 0 || msgs[0].GetHeader() == nil {
		return nil, errors.New("auditverify: bundle must start with a header")
	}
	header := msgs[0].GetHeader()
	keys := opts.Keys
	if keys == nil {
		if !opts.TrustHeaderKeys {
			return nil, ErrNoKeys
		}
		var err error
		if keys, err = KeySetFromProto(header.GetKeys()); err != nil {
			return nil, err
		}
	}

	rep := &Report{TenantID: header.GetTenantId(), Valid: true}
	expectSeq := int64(1)
	prevHash := ""
	if cp := header.GetStartCheckpoint(); cp != nil {
		pub, ok := keys[cp.GetKeyId()]
		if !ok {
			return nil, fmt.Errorf("auditverify: checkpoint key %q unknown", cp.GetKeyId())
		}
		if !VerifySignature(pub, CheckpointHash(cp), cp.GetSignature(), CanonVersionV2) {
			return fail(rep, cp.GetSeq(), "start checkpoint signature is invalid"), nil
		}
		rep.CheckpointsVerified++
		expectSeq = cp.GetSeq() + 1
		prevHash = cp.GetEntryHash()
	} else if header.GetStartSeq() > 1 {
		return nil, fmt.Errorf("auditverify: bundle starts at seq %d without a start checkpoint", header.GetStartSeq())
	}
	if header.GetStartSeq() > 0 && header.GetStartSeq() != expectSeq {
		return nil, fmt.Errorf("auditverify: header start_seq %d does not follow checkpoint seq %d", header.GetStartSeq(), expectSeq-1)
	}

	keyIDs := map[string]struct{}{}
	for _, m := range msgs[1:] {
		e := m.GetEntry()
		if e == nil {
			return nil, errors.New("auditverify: unexpected non-entry message after header")
		}
		if e.GetSeq() != expectSeq {
			return fail(rep, e.GetSeq(), fmt.Sprintf("gap: expected seq %d, found %d", expectSeq, e.GetSeq())), nil
		}
		if e.GetPreviousHash() != prevHash {
			return fail(rep, e.GetSeq(), "previous_hash does not link to the preceding entry"), nil
		}
		want, err := EntryHash(e, prevHash)
		if err != nil {
			return fail(rep, e.GetSeq(), err.Error()), nil
		}
		if want != e.GetEntryHash() {
			return fail(rep, e.GetSeq(), "entry_hash does not match the canonical content"), nil
		}
		pub, ok := keys[e.GetKeyId()]
		if !ok {
			return fail(rep, e.GetSeq(), fmt.Sprintf("unknown key %q", e.GetKeyId())), nil
		}
		if !VerifySignature(pub, e.GetEntryHash(), e.GetSignature(), e.GetCanonVersion()) {
			return fail(rep, e.GetSeq(), "signature is invalid"), nil
		}
		keyIDs[e.GetKeyId()] = struct{}{}
		if rep.FirstSeq == 0 {
			rep.FirstSeq = e.GetSeq()
		}
		rep.LastSeq, rep.EndHash = e.GetSeq(), e.GetEntryHash()
		rep.EntriesVerified++
		prevHash = e.GetEntryHash()
		expectSeq++
	}
	if cp := header.GetEndCheckpoint(); cp != nil && cp.GetSeq() == rep.LastSeq {
		pub, ok := keys[cp.GetKeyId()]
		if !ok {
			return fail(rep, cp.GetSeq(), fmt.Sprintf("unknown key %q", cp.GetKeyId())), nil
		}
		if cp.GetEntryHash() != rep.EndHash || !VerifySignature(pub, CheckpointHash(cp), cp.GetSignature(), CanonVersionV2) {
			return fail(rep, cp.GetSeq(), "end checkpoint does not match the chain"), nil
		}
		rep.CheckpointsVerified++
	}
	for k := range keyIDs {
		rep.KeyIDs = append(rep.KeyIDs, k)
	}
	return rep, nil
}

func fail(rep *Report, seq int64, reason string) *Report {
	rep.Valid = false
	rep.FirstInvalidSeq = seq
	rep.Reason = reason
	return rep
}

// ReadBundle decodes a length-delimited stream of ExportAuditEntriesResponse
// messages (uvarint length prefix, then protobuf bytes), the format
// WriteBundle produces for files.
func ReadBundle(r io.Reader) ([]*auditv1.ExportAuditEntriesResponse, error) {
	br := bufio.NewReader(r)
	var out []*auditv1.ExportAuditEntriesResponse
	for {
		n, err := binary.ReadUvarint(br)
		if errors.Is(err, io.EOF) {
			return out, nil
		}
		if err != nil {
			return nil, fmt.Errorf("auditverify: read length: %w", err)
		}
		buf := make([]byte, n)
		if _, err = io.ReadFull(br, buf); err != nil {
			return nil, fmt.Errorf("auditverify: read message: %w", err)
		}
		msg := &auditv1.ExportAuditEntriesResponse{}
		if err = proto.Unmarshal(buf, msg); err != nil {
			return nil, fmt.Errorf("auditverify: decode message: %w", err)
		}
		out = append(out, msg)
	}
}

// WriteBundle encodes messages in the ReadBundle format.
func WriteBundle(w io.Writer, msgs []*auditv1.ExportAuditEntriesResponse) error {
	var tmp [binary.MaxVarintLen64]byte
	for _, m := range msgs {
		raw, err := proto.Marshal(m)
		if err != nil {
			return err
		}
		n := binary.PutUvarint(tmp[:], uint64(len(raw)))
		if _, err = w.Write(tmp[:n]); err != nil {
			return err
		}
		if _, err = w.Write(raw); err != nil {
			return err
		}
	}
	return nil
}

// VerifyBundle reads a bundle from r and verifies it.
func VerifyBundle(r io.Reader, opts Options) (*Report, error) {
	msgs, err := ReadBundle(r)
	if err != nil {
		return nil, err
	}
	return Verify(msgs, opts)
}
