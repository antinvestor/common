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

// Package auditverify verifies exported audit bundles without the audit
// service. It mirrors, byte for byte, the canonical encoding implemented in
// service-authentication/apps/audit/service/business/canon.go; the golden
// vectors under testdata/ are shared between the two.
package auditverify

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strconv"
	"time"

	auditv1 "buf.build/gen/go/antinvestor/audit/protocolbuffers/go/audit/v1"
)

// Canonical encoding versions.
const (
	CanonVersionLegacy = 1
	CanonVersionV2     = 2
)

const canonTimeLayout = "2006-01-02T15:04:05.000000Z"

// Canonical returns the canon_v2 bytes of an exported entry (previous hash
// excluded).
func Canonical(e *auditv1.AuditEntryObject) []byte {
	var buf bytes.Buffer
	w := func(s string) {
		var tmp [binary.MaxVarintLen64]byte
		n := binary.PutUvarint(tmp[:], uint64(len(s)))
		buf.Write(tmp[:n])
		buf.WriteString(s)
	}
	relations, _ := CanonicalJSON(relationsMap(e))
	details, _ := CanonicalJSON(detailsMap(e))

	w(strconv.Itoa(int(e.GetCanonVersion())))
	w(e.GetTenantId())
	w(e.GetPartitionId())
	w(strconv.FormatInt(e.GetSeq(), 10))
	w(e.GetEntryId())
	w(e.GetService())
	w(strconv.Itoa(int(e.GetManifestVersion())))
	w(e.GetProfileId())
	w(e.GetOnBehalfOf())
	w(e.GetActorServiceAccountId())
	w(e.GetAction())
	w(e.GetResourceType())
	w(e.GetResourceId())
	w(strconv.FormatInt(e.GetResourceVersion(), 10))
	w(e.GetStateFrom())
	w(e.GetStateTo())
	w(e.GetTargetProfileId())
	w(e.GetDeviceId())
	w(e.GetDeviceKeyId())
	w(e.GetIpAddress())
	w(e.GetUserAgent())
	w(e.GetTraceId())
	w(e.GetCorrelationId())
	w(e.GetEventId())
	w(e.GetIntentId())
	w(e.GetInstanceId())
	w(e.GetPayloadHash())
	w(e.GetAuthorizationHash())
	w(e.GetPolicyHash())
	w(canonTime(e.GetOccurredAt().AsTime(), e.GetOccurredAt() != nil))
	w(canonTime(e.GetReceivedAt().AsTime(), e.GetReceivedAt() != nil))
	w(canonTime(e.GetCreatedAt().AsTime(), e.GetCreatedAt() != nil))
	w(string(relations))
	w(string(details))
	return buf.Bytes()
}

func detailsMap(e *auditv1.AuditEntryObject) map[string]any {
	if e.GetDetails() == nil {
		return map[string]any{}
	}
	return e.GetDetails().AsMap()
}

// relationsMap rebuilds the {"items": [...]} shape the service stores.
func relationsMap(e *auditv1.AuditEntryObject) map[string]any {
	rels := e.GetRelations()
	if len(rels) == 0 {
		return map[string]any{}
	}
	items := make([]any, 0, len(rels))
	for _, r := range rels {
		items = append(items, map[string]any{
			"parent_type": r.GetParentType(), "parent_id": r.GetParentId(),
			"child_type": r.GetChildType(), "child_id": r.GetChildId(), "action": r.GetAction(),
		})
	}
	return map[string]any{"items": items}
}

func canonTime(t time.Time, set bool) string {
	if !set || t.IsZero() {
		return ""
	}
	return t.UTC().Format(canonTimeLayout)
}

// CanonicalJSON encodes v deterministically: object keys sorted by their
// UTF-8 bytes, no insignificant whitespace, no HTML escaping, integral
// numbers below 1e15 without exponent, other numbers in shortest
// round-trip form. Numbers pass through float64 on every side.
func CanonicalJSON(v any) ([]byte, error) {
	var buf bytes.Buffer
	if err := writeCanonical(&buf, v); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeCanonical(buf *bytes.Buffer, v any) error {
	switch x := v.(type) {
	case nil:
		buf.WriteString("null")
	case bool:
		if x {
			buf.WriteString("true")
		} else {
			buf.WriteString("false")
		}
	case string:
		return writeJSONString(buf, x)
	case json.Number:
		f, err := x.Float64()
		if err != nil {
			return fmt.Errorf("canonical json: bad number %q", x)
		}
		return writeFloat(buf, f)
	case float64:
		return writeFloat(buf, x)
	case float32:
		return writeFloat(buf, float64(x))
	case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
		writeInteger(buf, x)
	case map[string]any:
		return writeObject(buf, x)
	case []any:
		buf.WriteByte('[')
		for i, item := range x {
			if i > 0 {
				buf.WriteByte(',')
			}
			if err := writeCanonical(buf, item); err != nil {
				return err
			}
		}
		buf.WriteByte(']')
	default:
		raw, err := json.Marshal(v)
		if err != nil {
			return err
		}
		dec := json.NewDecoder(bytes.NewReader(raw))
		dec.UseNumber()
		var generic any
		if err = dec.Decode(&generic); err != nil {
			return err
		}
		return writeCanonical(buf, generic)
	}
	return nil
}

func writeInteger(buf *bytes.Buffer, v any) {
	switch x := v.(type) {
	case int:
		buf.WriteString(strconv.FormatInt(int64(x), 10))
	case int8:
		buf.WriteString(strconv.FormatInt(int64(x), 10))
	case int16:
		buf.WriteString(strconv.FormatInt(int64(x), 10))
	case int32:
		buf.WriteString(strconv.FormatInt(int64(x), 10))
	case int64:
		buf.WriteString(strconv.FormatInt(x, 10))
	case uint:
		buf.WriteString(strconv.FormatUint(uint64(x), 10))
	case uint8:
		buf.WriteString(strconv.FormatUint(uint64(x), 10))
	case uint16:
		buf.WriteString(strconv.FormatUint(uint64(x), 10))
	case uint32:
		buf.WriteString(strconv.FormatUint(uint64(x), 10))
	case uint64:
		buf.WriteString(strconv.FormatUint(x, 10))
	}
}

func writeObject(buf *bytes.Buffer, m map[string]any) error {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	buf.WriteByte('{')
	for i, k := range keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		if err := writeJSONString(buf, k); err != nil {
			return err
		}
		buf.WriteByte(':')
		if err := writeCanonical(buf, m[k]); err != nil {
			return err
		}
	}
	buf.WriteByte('}')
	return nil
}

func writeFloat(buf *bytes.Buffer, f float64) error {
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return fmt.Errorf("canonical json: non-finite number %v", f)
	}
	if f == math.Trunc(f) && math.Abs(f) < 1e15 {
		buf.WriteString(strconv.FormatInt(int64(f), 10))
		return nil
	}
	buf.WriteString(strconv.FormatFloat(f, 'g', -1, 64))
	return nil
}

func writeJSONString(buf *bytes.Buffer, s string) error {
	enc := json.NewEncoder(buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(s); err != nil {
		return err
	}
	buf.Truncate(buf.Len() - 1)
	return nil
}

// EntryHashV2 is hex(SHA-256(canon_v2(entry) ‖ previous_hash_bytes)).
func EntryHashV2(e *auditv1.AuditEntryObject, previousHash string) string {
	h := sha256.New()
	h.Write(Canonical(e))
	if prev, err := hex.DecodeString(previousHash); err == nil {
		h.Write(prev)
	} else {
		h.Write([]byte(previousHash))
	}
	return hex.EncodeToString(h.Sum(nil))
}

// EntryHashV1 reproduces the pre-v2 pipe-delimited pre-image for entries
// with canon_version 1. It must never change.
func EntryHashV1(e *auditv1.AuditEntryObject, previousHash string) string {
	var detailsJSON []byte
	if e.GetDetails() == nil {
		detailsJSON = []byte("null")
	} else {
		detailsJSON, _ = json.Marshal(e.GetDetails().AsMap())
	}
	createdAt := ""
	if e.GetCreatedAt() != nil {
		createdAt = e.GetCreatedAt().AsTime().UTC().Format(canonTimeLayout)
	}
	payload := fmt.Sprintf("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s",
		e.GetProfileId(), e.GetAction(), e.GetResourceType(), e.GetResourceId(), e.GetService(),
		string(detailsJSON), e.GetIpAddress(), e.GetUserAgent(), e.GetDeviceId(),
		e.GetTargetProfileId(), e.GetTraceId(), createdAt, previousHash)
	sum := sha256.Sum256([]byte(payload))
	return hex.EncodeToString(sum[:])
}

// EntryHash dispatches on canon_version.
func EntryHash(e *auditv1.AuditEntryObject, previousHash string) (string, error) {
	switch e.GetCanonVersion() {
	case CanonVersionLegacy:
		return EntryHashV1(e, previousHash), nil
	case CanonVersionV2:
		return EntryHashV2(e, previousHash), nil
	default:
		return "", fmt.Errorf("unsupported canon_version %d", e.GetCanonVersion())
	}
}

// CheckpointHash is hex(SHA-256("chk" ‖ tenant ‖ seq ‖ entry_hash ‖ created_at)).
func CheckpointHash(c *auditv1.AuditCheckpoint) string {
	var buf bytes.Buffer
	for _, s := range []string{"chk", c.GetTenantId(), strconv.FormatInt(c.GetSeq(), 10), c.GetEntryHash(),
		canonTime(c.GetCreatedAt().AsTime(), c.GetCreatedAt() != nil)} {
		var tmp [binary.MaxVarintLen64]byte
		n := binary.PutUvarint(tmp[:], uint64(len(s)))
		buf.Write(tmp[:n])
		buf.WriteString(s)
	}
	sum := sha256.Sum256(buf.Bytes())
	return hex.EncodeToString(sum[:])
}

// VerifySignature checks sigHex over hashHex under canonVersion rules:
// version 1 signed the hex string bytes, version 2 the raw digest.
func VerifySignature(pub ed25519.PublicKey, hashHex, sigHex string, canonVersion int32) bool {
	if len(pub) != ed25519.PublicKeySize {
		return false
	}
	var msg []byte
	switch canonVersion {
	case CanonVersionLegacy:
		msg = []byte(hashHex)
	case CanonVersionV2:
		raw, err := hex.DecodeString(hashHex)
		if err != nil || len(raw) != 32 {
			return false
		}
		msg = raw
	default:
		return false
	}
	sig, err := hex.DecodeString(sigHex)
	if err != nil {
		return false
	}
	return ed25519.Verify(pub, msg, sig)
}
