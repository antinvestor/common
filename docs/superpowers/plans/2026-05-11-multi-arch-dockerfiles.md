# Multi-Arch Dockerfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every Antinvestor application Docker image is published as a multi-arch manifest (`linux/amd64` + `linux/arm64`), fix the one silent regression (`service-thesa`), and prevent future regressions with a CI lint guard.

**Architecture:** Add a small bash lint script + reusable GitHub workflow to `common/`. Wire a caller workflow into each of 10 repos. Fix 5 existing Dockerfile/workflow issues. Verify via post-merge multi-arch manifest inspection.

**Tech Stack:** Bash (grep/awk only), GitHub Actions (`workflow_call`), Docker buildx + QEMU (already in place), `cgr.dev/chainguard/static` base images.

**Spec:** `common/docs/superpowers/specs/2026-05-11-multi-arch-dockerfiles-design.md`

**Refinement from spec:** Per-repo CI wiring uses a standalone caller workflow file (`.github/workflows/dockerfile-lint.yml`) per repo rather than adding a new job to each repo's existing `ci.yaml`. Reasons: (a) `builder/` has no unified `ci.yaml`; (b) `service-fintech/` has both `ci.yaml` and `ci.yml` (vestigial), which would force a decision; (c) a standalone file is uniform across all 10 repos and easier to roll back if needed. End result is identical — lint runs on every PR.

---

## Phase A — Build the lint guard in `common/`

### Task 1: Create test fixtures and harness for the lint script

**Files:**
- Create: `common/scripts/testdata/multiarch/good/apps/default/Dockerfile`
- Create: `common/scripts/testdata/multiarch/missing-args/apps/default/Dockerfile`
- Create: `common/scripts/testdata/multiarch/no-buildplatform/apps/default/Dockerfile`
- Create: `common/scripts/testdata/multiarch/opt-out-amd64/apps/default/Dockerfile`
- Create: `common/scripts/testdata/multiarch/missing-goos/apps/default/Dockerfile`
- Create: `common/scripts/test-check-dockerfile-multiarch.sh`

- [ ] **Step 1: Write the GOOD fixture** (canonical pattern from `service-payment/apps/default/Dockerfile`)

Create `common/scripts/testdata/multiarch/good/apps/default/Dockerfile`:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
```

- [ ] **Step 2: Write the MISSING-ARGS fixture** (the service-thesa bug)

Create `common/scripts/testdata/multiarch/missing-args/apps/default/Dockerfile`:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
```

- [ ] **Step 3: Write the NO-BUILDPLATFORM fixture**

Create `common/scripts/testdata/multiarch/no-buildplatform/apps/default/Dockerfile`:

```dockerfile
FROM golang:1.26 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
```

- [ ] **Step 4: Write the OPT-OUT fixture** (CGO-heavy app like `service-files/apps/ocr`)

Create `common/scripts/testdata/multiarch/opt-out-amd64/apps/default/Dockerfile`:

```dockerfile
# build-platforms: linux/amd64
FROM ubuntu:22.04 AS builder

WORKDIR /app
RUN apt-get update && apt-get install -y libtesseract-dev
COPY . .
RUN go build -o /app/binary ./cmd/main.go

FROM ubuntu:22.04
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
```

- [ ] **Step 5: Write the MISSING-GOOS fixture** (declares ARGs but forgets to use them on `go build`)

Create `common/scripts/testdata/multiarch/missing-goos/apps/default/Dockerfile`:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
```

- [ ] **Step 6: Write the test harness**

Create `common/scripts/test-check-dockerfile-multiarch.sh`:

```bash
#!/usr/bin/env bash
# Test harness for check-dockerfile-multiarch.sh
# Runs the script against each testdata fixture and asserts expected output.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/check-dockerfile-multiarch.sh"
TESTDATA="$SCRIPT_DIR/testdata/multiarch"

if [[ ! -x "$SCRIPT" ]]; then
    echo "ERROR: $SCRIPT does not exist or is not executable" >&2
    exit 2
fi

failures=0

run_case() {
    local name="$1"
    local expect_exit="$2"
    local expect_pattern="$3"

    local out
    out=$(cd "$TESTDATA/$name" && "$SCRIPT" 2>&1)
    local actual_exit=$?

    if [[ "$actual_exit" -ne "$expect_exit" ]]; then
        echo "FAIL [$name]: expected exit $expect_exit, got $actual_exit"
        echo "Output was:"
        echo "$out" | sed 's/^/  /'
        failures=$((failures + 1))
        return
    fi

    if ! echo "$out" | grep -qE "$expect_pattern"; then
        echo "FAIL [$name]: output did not match expected pattern: $expect_pattern"
        echo "Output was:"
        echo "$out" | sed 's/^/  /'
        failures=$((failures + 1))
        return
    fi

    echo "PASS [$name]"
}

run_case "good"             0 '^PASS '
run_case "missing-args"     1 'FAIL.*TARGETARCH'
run_case "no-buildplatform" 1 'FAIL.*BUILDPLATFORM'
run_case "opt-out-amd64"    0 '^SKIP '
run_case "missing-goos"     1 'FAIL.*GOOS=\$\{TARGETOS\}|FAIL.*GOARCH=\$\{TARGETARCH\}'

if [[ "$failures" -gt 0 ]]; then
    echo "$failures test case(s) failed"
    exit 1
fi
echo "All test cases passed"
```

- [ ] **Step 7: Make it executable**

```bash
chmod +x /home/j/code/antinvestor/common/scripts/test-check-dockerfile-multiarch.sh
```

- [ ] **Step 8: Run the harness — expect it to fail because the script doesn't exist yet**

```bash
/home/j/code/antinvestor/common/scripts/test-check-dockerfile-multiarch.sh
```

Expected: `ERROR: .../check-dockerfile-multiarch.sh does not exist or is not executable`, exit code 2.

### Task 2: Implement the lint script

**Files:**
- Create: `common/scripts/check-dockerfile-multiarch.sh`

- [ ] **Step 1: Write the script**

Create `common/scripts/check-dockerfile-multiarch.sh`:

```bash
#!/usr/bin/env bash
# check-dockerfile-multiarch.sh
#
# Verifies every Dockerfile under ./apps/ follows the canonical multi-arch
# build pattern, or has an explicit `# build-platforms:` opt-out comment.
#
# Output: one line per file (PASS/FAIL/SKIP). Exit 0 if no FAILs, 1 otherwise.

set -u

failures=0
checked=0

check_file() {
    local file="$1"
    checked=$((checked + 1))

    # Opt-out comment short-circuits all checks.
    if grep -qE '^# build-platforms:' "$file"; then
        echo "SKIP $file: amd64-only (or custom) by design"
        return 0
    fi

    local content
    content=$(cat "$file")

    local builder_from
    builder_from=$(grep -E '^FROM .* AS [Bb]uilder' "$file" | head -1)
    if [[ -z "$builder_from" ]]; then
        builder_from=$(grep -E '^FROM ' "$file" | head -1)
    fi

    if ! echo "$builder_from" | grep -q -- '--platform=\$BUILDPLATFORM'; then
        echo "FAIL $file: builder FROM missing --platform=\$BUILDPLATFORM"
        failures=$((failures + 1))
        return 1
    fi

    local refs_targetos refs_targetarch
    refs_targetos=$(grep -cE '\$\{TARGETOS\}|\$TARGETOS\b' "$file" || true)
    refs_targetarch=$(grep -cE '\$\{TARGETARCH\}|\$TARGETARCH\b' "$file" || true)

    if [[ "$refs_targetos" -gt 0 ]] && ! grep -qE '^[[:space:]]*ARG[[:space:]]+TARGETOS' "$file"; then
        echo "FAIL $file: builder stage references \${TARGETOS} but does not declare ARG TARGETOS"
        failures=$((failures + 1))
        return 1
    fi

    if [[ "$refs_targetarch" -gt 0 ]] && ! grep -qE '^[[:space:]]*ARG[[:space:]]+TARGETARCH' "$file"; then
        echo "FAIL $file: builder stage references \${TARGETARCH} but does not declare ARG TARGETARCH"
        failures=$((failures + 1))
        return 1
    fi

    if grep -qE '(^|[[:space:]])go build([[:space:]]|$)' "$file"; then
        if ! grep -qE 'GOOS=\$\{TARGETOS\}.*GOARCH=\$\{TARGETARCH\}|GOARCH=\$\{TARGETARCH\}.*GOOS=\$\{TARGETOS\}' "$file"; then
            echo "FAIL $file: go build present without GOOS=\${TARGETOS} GOARCH=\${TARGETARCH} and no # build-platforms: opt-out"
            failures=$((failures + 1))
            return 1
        fi
    fi

    echo "PASS $file"
    return 0
}

if [[ ! -d ./apps ]]; then
    echo "No ./apps directory found in $(pwd) — nothing to lint."
    exit 0
fi

while IFS= read -r -d '' f; do
    check_file "$f"
done < <(find ./apps -name Dockerfile -type f -print0)

if [[ "$checked" -eq 0 ]]; then
    echo "No Dockerfiles found under ./apps — nothing to lint."
    exit 0
fi

echo ""
echo "Checked $checked Dockerfile(s); $failures failure(s)."

if [[ "$failures" -gt 0 ]]; then
    exit 1
fi
exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/j/code/antinvestor/common/scripts/check-dockerfile-multiarch.sh
```

- [ ] **Step 3: Run the test harness — expect all 5 cases to pass**

```bash
/home/j/code/antinvestor/common/scripts/test-check-dockerfile-multiarch.sh
```

Expected:
```
PASS [good]
PASS [missing-args]
PASS [no-buildplatform]
PASS [opt-out-amd64]
PASS [missing-goos]
All test cases passed
```

If a case fails, refine the script. Common issues to watch for: regex escaping for `${}` in grep patterns; `find` glob behavior when no matches.

- [ ] **Step 4: Run script against the current 10 repos** (sanity baseline)

```bash
for d in builder service-authentication service-commerce service-files service-fintech service-notification service-payment service-profile service-thesa service-trustage; do
    echo "=== $d ==="
    (cd /home/j/code/antinvestor/$d && /home/j/code/antinvestor/common/scripts/check-dockerfile-multiarch.sh)
done
```

Expected outcomes:
- `service-thesa` → exit 1, with FAIL on `apps/default/Dockerfile` for missing `ARG TARGETARCH`.
- `service-files` → exit 0, with `SKIP` on `apps/ocr/Dockerfile`.
- All others → exit 0, all `PASS`.

If any other repo unexpectedly fails or passes, the script regex needs adjustment.

### Task 3: Create the reusable workflow

**Files:**
- Create: `common/.github/workflows/dockerfile-lint.yml`

- [ ] **Step 1: Write the workflow**

Create `common/.github/workflows/dockerfile-lint.yml`:

```yaml
name: Dockerfile Multi-Arch Lint

on:
  workflow_call: {}

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout caller repo
        uses: actions/checkout@v6

      - name: Fetch lint script from common@main
        run: |
          set -e
          curl -fsSL \
            -o /tmp/check-dockerfile-multiarch.sh \
            https://raw.githubusercontent.com/antinvestor/common/main/scripts/check-dockerfile-multiarch.sh
          chmod +x /tmp/check-dockerfile-multiarch.sh

      - name: Lint Dockerfiles
        run: /tmp/check-dockerfile-multiarch.sh
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/j/code/antinvestor/common/.github/workflows/dockerfile-lint.yml'))"
```

Expected: no output, exit code 0.

### Task 4: Commit `common/` changes

- [ ] **Step 1: Stage and commit**

```bash
cd /home/j/code/antinvestor/common
git add scripts/check-dockerfile-multiarch.sh \
        scripts/test-check-dockerfile-multiarch.sh \
        scripts/testdata/multiarch \
        .github/workflows/dockerfile-lint.yml \
        docs/superpowers/specs/2026-05-11-multi-arch-dockerfiles-design.md \
        docs/superpowers/plans/2026-05-11-multi-arch-dockerfiles.md
git status
```

Expected: the 4 script/workflow files, the 5 testdata Dockerfiles, plus spec + plan markdown.

```bash
git commit -m "$(cat <<'EOF'
add Dockerfile multi-arch lint guard

Introduces a small bash script + reusable workflow to verify every
Dockerfile under ./apps/ follows the canonical multi-arch pattern
(BUILDPLATFORM pinning, declared TARGETOS/TARGETARCH args, explicit
GOOS/GOARCH passthrough), with opt-out via # build-platforms: comment.

Caller repos invoke via:
  uses: antinvestor/common/.github/workflows/dockerfile-lint.yml@main
EOF
)"
```

- [ ] **Step 2: Push** (only if user confirms — do not auto-push)

Wait for user instruction before pushing.

---

## Phase B — Fix the existing issues

### Task 5: Fix `service-thesa/apps/default/Dockerfile`

**Files:**
- Modify: `service-thesa/apps/default/Dockerfile:2-4`

- [ ] **Step 1: Confirm current state**

```bash
sed -n '1,5p' /home/j/code/antinvestor/service-thesa/apps/default/Dockerfile
```

Expected output:
```
# Stage 1: Build Go BFF
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder

WORKDIR /build
```

- [ ] **Step 2: Edit the Dockerfile** (use Edit tool)

Change:
```
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder

WORKDIR /build
```

To:
```
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /build
```

- [ ] **Step 3: Run the lint script against `service-thesa`**

```bash
cd /home/j/code/antinvestor/service-thesa && /home/j/code/antinvestor/common/scripts/check-dockerfile-multiarch.sh
```

Expected: `PASS ./apps/default/Dockerfile`, exit 0.

- [ ] **Step 4: Commit**

```bash
cd /home/j/code/antinvestor/service-thesa
git add apps/default/Dockerfile
git commit -m "$(cat <<'EOF'
fix multi-arch build in apps/default Dockerfile

Builder stage referenced ${TARGETOS} and ${TARGETARCH} without declaring
them as ARGs, so they expanded to empty strings. Go fell back to the
host architecture, meaning the linux/arm64 image manifest silently
contained an amd64 binary.

Adds the missing ARG declarations after the FROM line, matching the
canonical pattern used by every other Dockerfile in this org.
EOF
)"
```

### Task 6: Clean up `service-trustage` Dockerfiles

**Files:**
- Modify: `service-trustage/apps/default/Dockerfile:1-3`
- Modify: `service-trustage/apps/formstore/Dockerfile:1-3`
- Modify: `service-trustage/apps/queue/Dockerfile:1-3`

- [ ] **Step 1: Confirm current state**

```bash
for app in default formstore queue; do
    echo "=== $app ==="
    sed -n '1,5p' /home/j/code/antinvestor/service-trustage/apps/$app/Dockerfile
done
```

Expected — each file starts with:
```
ARG TARGETOS
ARG TARGETARCH

# ---------- Builder ----------
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
```

- [ ] **Step 2: Remove dead top-level ARGs from `apps/default/Dockerfile`**

Use Edit to replace:
```
ARG TARGETOS
ARG TARGETARCH

# ---------- Builder ----------
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
```

With:
```
# ---------- Builder ----------
FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
```

- [ ] **Step 3: Repeat for `apps/formstore/Dockerfile`**

Same edit as Step 2, on `service-trustage/apps/formstore/Dockerfile`.

- [ ] **Step 4: Repeat for `apps/queue/Dockerfile`**

Same edit as Step 2, on `service-trustage/apps/queue/Dockerfile`.

- [ ] **Step 5: Run the lint script**

```bash
cd /home/j/code/antinvestor/service-trustage && /home/j/code/antinvestor/common/scripts/check-dockerfile-multiarch.sh
```

Expected: 3 × `PASS`, exit 0.

- [ ] **Step 6: Commit**

```bash
cd /home/j/code/antinvestor/service-trustage
git add apps/default/Dockerfile apps/formstore/Dockerfile apps/queue/Dockerfile
git commit -m "$(cat <<'EOF'
remove dead top-level TARGETOS/TARGETARCH ARGs from Dockerfiles

The global ARGs (before any FROM) applied to no stage and were
harmless noise. The in-stage ARG declarations after the builder
FROM are what BuildKit actually consumes.
EOF
)"
```

### Task 7: Patch `builder/.github/workflows/release.yml`

**Files:**
- Modify: `builder/.github/workflows/release.yml:99-112`

- [ ] **Step 1: Confirm current state**

```bash
sed -n '98,113p' /home/j/code/antinvestor/builder/.github/workflows/release.yml
```

Expected: a `Build and Push Image` step with `platforms: linux/amd64,linux/arm64` hardcoded.

- [ ] **Step 2: Insert a new step before the build-push step**

Use Edit to replace:
```yaml
      # Push to Github Container Registry
      - name: Build and Push Image to Github Container Registry
        uses: docker/build-push-action@v7
        with:
          context: ./
          file: ./${{ env.APP_PATH }}/Dockerfile
          push: true
          platforms: linux/amd64,linux/arm64
```

With:
```yaml
      # Honor per-Dockerfile `# build-platforms:` opt-out comment.
      # Mirrors the parsing in common/.github/workflows/docker-release.yml.
      - name: Determine build platforms
        id: platforms
        run: |
          DOCKERFILE="./${{ env.APP_PATH }}/Dockerfile"
          HINT=$(grep -m1 -E '^# build-platforms:' "$DOCKERFILE" 2>/dev/null | sed -E 's/^# build-platforms:[[:space:]]*//')
          if [[ -n "$HINT" ]]; then
            echo "Using per-Dockerfile platforms hint: $HINT"
            echo "value=$HINT" >> $GITHUB_OUTPUT
          else
            echo "value=linux/amd64,linux/arm64" >> $GITHUB_OUTPUT
          fi

      # Push to Github Container Registry
      - name: Build and Push Image to Github Container Registry
        uses: docker/build-push-action@v7
        with:
          context: ./
          file: ./${{ env.APP_PATH }}/Dockerfile
          push: true
          platforms: ${{ steps.platforms.outputs.value }}
```

- [ ] **Step 3: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/j/code/antinvestor/builder/.github/workflows/release.yml'))"
```

Expected: no output, exit 0.

- [ ] **Step 4: Diff-check against the canonical parsing in `common/`**

```bash
diff <(sed -n '/Determine build platforms/,/^$/p' /home/j/code/antinvestor/builder/.github/workflows/release.yml) \
     <(sed -n '/id: platforms/,/^      - /p' /home/j/code/antinvestor/common/.github/workflows/docker-release.yml | head -14)
```

Manually inspect — the `grep`/`sed` regex and the default fallback must match character-for-character. (The wrapping YAML keys differ, that's fine.)

- [ ] **Step 5: Commit**

```bash
cd /home/j/code/antinvestor/builder
git add .github/workflows/release.yml
git commit -m "$(cat <<'EOF'
honor per-Dockerfile # build-platforms: opt-out in release workflow

Matches the parsing logic in
antinvestor/common/.github/workflows/docker-release.yml so that
builder/apps/* Dockerfiles can opt out of arm64 via the same
comment convention used elsewhere in the org. Default remains
linux/amd64,linux/arm64.
EOF
)"
```

---

## Phase C — Wire CI per repo

### Task 8: Add `dockerfile-lint.yml` caller workflow to each of 10 repos

The same one-file caller workflow goes into every repo. Repos: `builder`, `service-authentication`, `service-commerce`, `service-files`, `service-fintech`, `service-notification`, `service-payment`, `service-profile`, `service-thesa`, `service-trustage`.

**Files (one per repo):**
- Create: `<repo>/.github/workflows/dockerfile-lint.yml`

- [ ] **Step 1: Write the caller workflow content** (used for all 10 repos verbatim)

```yaml
# Copyright 2023-2026 Ant Investor Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

name: Dockerfile Multi-Arch Lint
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  lint:
    permissions:
      contents: read
    uses: antinvestor/common/.github/workflows/dockerfile-lint.yml@main
```

- [ ] **Step 2: Create the file in each of the 10 repos**

Use the Write tool to create the file at each path. For `builder`, omit the Apache 2.0 header (its other workflows do not use it; match the local convention). Inspect `builder/.github/workflows/release.yml` line 1 — no header. Same for `common`. For all 9 `service-*` repos, keep the header (matches their existing convention).

Concrete paths:
- `/home/j/code/antinvestor/builder/.github/workflows/dockerfile-lint.yml` (no Apache header)
- `/home/j/code/antinvestor/service-authentication/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-commerce/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-files/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-fintech/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-notification/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-payment/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-profile/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-thesa/.github/workflows/dockerfile-lint.yml`
- `/home/j/code/antinvestor/service-trustage/.github/workflows/dockerfile-lint.yml`

- [ ] **Step 3: Validate YAML syntax in each repo**

```bash
for d in builder service-authentication service-commerce service-files service-fintech service-notification service-payment service-profile service-thesa service-trustage; do
    python3 -c "import yaml; yaml.safe_load(open('/home/j/code/antinvestor/$d/.github/workflows/dockerfile-lint.yml'))" && echo "$d OK"
done
```

Expected: 10 lines of `<repo> OK`.

- [ ] **Step 4: Commit per repo**

For each of the 10 repos, run:

```bash
cd /home/j/code/antinvestor/<repo>
git add .github/workflows/dockerfile-lint.yml
git commit -m "$(cat <<'EOF'
add Dockerfile multi-arch lint workflow

Calls antinvestor/common/.github/workflows/dockerfile-lint.yml on
every PR. The shared workflow runs scripts/check-dockerfile-multiarch.sh
against ./apps/**/Dockerfile to ensure each follows the canonical
multi-arch build pattern (or has an explicit # build-platforms: opt-out).
EOF
)"
```

Replace `<repo>` with each of the 10 repo names. Do not push until the user confirms.

---

## Phase D — Verification

### Task 9: Multi-arch image validation after `service-thesa` release

This task is **post-merge** — runs only after the `service-thesa` Dockerfile fix is merged and a new tag (`v*.*.*`) is pushed.

- [ ] **Step 1: Wait for `service-thesa` release workflow to complete**

After a new tag is pushed, watch the actions tab at https://github.com/antinvestor/service-thesa/actions. Wait for the `docker` job in the `Release` workflow to succeed.

- [ ] **Step 2: Inspect the resulting multi-arch manifest**

```bash
docker buildx imagetools inspect ghcr.io/antinvestor/service-thesa:<tag>
```

Expected: output includes both `linux/amd64` and `linux/arm64` platforms in the manifest list. Sample expected line: `Platform: linux/arm64`.

- [ ] **Step 3: Verify the arm64 binary is actually arm64** (the real fix proof)

```bash
docker run --rm --platform=linux/arm64 ghcr.io/antinvestor/service-thesa:<tag> --version
```

Expected: prints version info and exits cleanly.

Pre-fix failure mode (for reference): `exec format error` or immediate `SIGSEGV`, because the arm64 manifest contained an x86_64 binary.

- [ ] **Step 4: Spot-check one other repo's multi-arch manifest** (regression sanity)

```bash
docker buildx imagetools inspect ghcr.io/antinvestor/service-payment:<latest-tag>
```

Expected: both `linux/amd64` and `linux/arm64` present, unchanged from before this work.

---

## Self-Review

Spec coverage check (Acceptance Criteria from spec):
- [x] `service-thesa/apps/default/Dockerfile` ARG fix — Task 5
- [x] `service-trustage` cleanup — Task 6
- [x] `builder/.github/workflows/release.yml` HINT parsing — Task 7
- [x] `common/scripts/check-dockerfile-multiarch.sh` exists, exits 0 — Task 2
- [x] `common/.github/workflows/dockerfile-lint.yml` exists, `workflow_call` — Task 3
- [x] 10 repos' CI wired — Task 8
- [x] Next `service-thesa` release produces arm64 manifest with arm64 binary — Task 9

No placeholders detected. Method/file names consistent across tasks (`check-dockerfile-multiarch.sh`, `dockerfile-lint.yml`, `# build-platforms:`).

No spec gaps.
