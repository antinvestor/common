# Multi-Arch Dockerfiles — Design

**Date:** 2026-05-11
**Scope:** All Antinvestor service repos (10 services + builder) with apps producing Docker images
**Goal:** Ensure every application's Docker image is published as a multi-arch manifest (`linux/amd64` + `linux/arm64`), and prevent silent regressions in the future.

## Background

An audit of all 44 Dockerfiles across 11 repos found that the existing multi-arch infrastructure is largely correct:

- 41/44 Dockerfiles correctly use `FROM --platform=$BUILDPLATFORM`, declare `ARG TARGETOS` / `ARG TARGETARCH`, and build with `CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}`.
- 1/44 is intentionally `linux/amd64`-only (`service-files/apps/ocr/Dockerfile`) due to CGO + libtesseract requirements. Opt-out is declared via `# build-platforms: linux/amd64` and respected by the centralized release workflow.
- 10/11 repos already call `antinvestor/common/.github/workflows/docker-release.yml`, which defaults to `linux/amd64,linux/arm64` and honors the `# build-platforms:` opt-out comment.

Three real issues remain:

1. **`service-thesa/apps/default/Dockerfile`** — references `${TARGETOS}` and `${TARGETARCH}` but does not declare them as build args inside the builder stage. They expand to empty strings, Go falls back to host arch, and the arm64 manifest silently contains an amd64 binary.
2. **`service-trustage/apps/{default,formstore,queue}/Dockerfile`** — declare dead top-level `ARG TARGETOS` / `ARG TARGETARCH` before any `FROM`. Harmless but noisy.
3. **`builder/.github/workflows/release.yml`** — self-contained release workflow with hardcoded `platforms:`; does not parse `# build-platforms:` opt-out comments. Currently works because no builder Dockerfile opts out, but inconsistent with the other 10 repos.

A lint check in CI would have caught issue (1) the day it was introduced. Adding one prevents the next silent regression.

## Architecture

Three buckets of work:

### Bucket 1 — Fix existing issues (5 files)

| File | Action |
|---|---|
| `service-thesa/apps/default/Dockerfile` | Add `ARG TARGETOS` and `ARG TARGETARCH` immediately after `FROM --platform=$BUILDPLATFORM golang:1.26 AS builder`, matching the canonical pattern in `service-payment/apps/default/Dockerfile` lines 3-4. |
| `service-trustage/apps/default/Dockerfile` | Remove the dead top-level `ARG TARGETOS` / `ARG TARGETARCH` lines (in-stage ARGs already do the right thing). |
| `service-trustage/apps/formstore/Dockerfile` | Same cleanup. |
| `service-trustage/apps/queue/Dockerfile` | Same cleanup. |
| `builder/.github/workflows/release.yml` | Patch in place (option **b**): add the `# build-platforms:` HINT-parsing step from `common/.github/workflows/docker-release.yml` lines 48-59. Keep the local workflow's existing image-naming logic. |

### Bucket 2 — Lint guard in `common/`

New files:

- `common/scripts/check-dockerfile-multiarch.sh` — bash script (~60 lines) that walks `./apps/**/Dockerfile` and validates the canonical multi-arch pattern.
- `common/.github/workflows/dockerfile-lint.yml` — reusable workflow (`workflow_call`) that fetches and runs the script against the caller repo.

### Bucket 3 — CI wiring (10 repos)

Add one job block to each repo's existing `.github/workflows/ci.yaml`:

```yaml
dockerfile-lint:
  uses: antinvestor/common/.github/workflows/dockerfile-lint.yml@main
```

Repos to wire: `builder`, `service-authentication`, `service-commerce`, `service-files`, `service-fintech`, `service-notification`, `service-payment`, `service-profile`, `service-thesa`, `service-trustage`. (10 — `common` itself has no `apps/` directory but can still run the lint as a safety net if desired; out of scope for this iteration.)

## Components

### `common/scripts/check-dockerfile-multiarch.sh`

Inputs: walks `./apps` from the working directory, finds every file named `Dockerfile`.

For each file, runs these checks inside the builder stage (the stage that contains `go build` or the equivalent build command):

1. **Platform pinning** — the builder `FROM` line must include `--platform=$BUILDPLATFORM`, *unless* the file has a `# build-platforms:` opt-out comment.
2. **ARG declaration** — if `${TARGETOS}` or `${TARGETARCH}` is referenced anywhere in the file, both `ARG TARGETOS` and `ARG TARGETARCH` must be declared inside the same stage that references them.
3. **GOOS/GOARCH passthrough** — if `go build` is present and the file lacks both a `# build-platforms:` opt-out and explicit `GOOS=${TARGETOS} GOARCH=${TARGETARCH}` on the build command, fail.

Output format, one line per file:
- `PASS <path>`
- `FAIL <path>: <specific reason>`
- `SKIP <path>: amd64-only by design`

Exit code: 0 if no FAILs (SKIPs do not affect exit), 1 if any FAIL.

Uses `set -u` (catch unset vars) but not `set -e` (continue checking after a single file's check misses).

### `common/.github/workflows/dockerfile-lint.yml`

Approximate shape:

```yaml
name: Dockerfile Multi-Arch Lint
on:
  workflow_call: {}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Fetch lint script
        run: |
          curl -fsSL -o /tmp/check-dockerfile-multiarch.sh \
            https://raw.githubusercontent.com/antinvestor/common/main/scripts/check-dockerfile-multiarch.sh
          chmod +x /tmp/check-dockerfile-multiarch.sh
      - name: Lint Dockerfiles
        run: /tmp/check-dockerfile-multiarch.sh
```

Pinning to `@main` matches the existing `docker-release.yml` and `publish-release.yml` callers. Can be retagged later without changing callers.

### `builder/.github/workflows/release.yml` patch

Add a `platforms` step before the `docker/build-push-action` step, copied verbatim from `common/.github/workflows/docker-release.yml` lines 48-59:

```yaml
- id: platforms
  run: |
    DOCKERFILE="./${{ matrix.app }}/Dockerfile"
    HINT=$(grep -m1 -E '^# build-platforms:' "$DOCKERFILE" 2>/dev/null | sed -E 's/^# build-platforms:[[:space:]]*//')
    if [[ -n "$HINT" ]]; then
      echo "value=$HINT" >> $GITHUB_OUTPUT
    else
      echo "value=linux/amd64,linux/arm64" >> $GITHUB_OUTPUT
    fi
```

Then change the build-push step's `platforms:` input from the hardcoded value to `${{ steps.platforms.outputs.value }}`.

## Data Flow

### Local developer flow

1. Engineer edits a Dockerfile under `apps/**/Dockerfile`.
2. Optionally runs the script directly: `bash <(curl -s https://raw.githubusercontent.com/antinvestor/common/main/scripts/check-dockerfile-multiarch.sh)`.
3. Sees `PASS` / `FAIL` / `SKIP` output per file; fixes any FAILs before pushing.

### CI flow (per PR / push, per repo)

1. PR opened or pushed → repo's `ci.yaml` triggers → new `dockerfile-lint` job runs alongside existing jobs.
2. Job checks out caller repo, fetches `check-dockerfile-multiarch.sh` from `common@main`, runs it.
3. Any FAIL → job fails → PR blocked. Existing build/test jobs are unaffected.

### Release flow (10 repos using `common/docker-release.yml`)

Unchanged. Tag pushed → workflow discovers Dockerfiles → reads `# build-platforms:` hints → buildx + QEMU → push multi-arch manifest to ghcr.io.

### Release flow (builder repo, after patch)

1. Tag pushed → `builder/.github/workflows/release.yml` triggers (local workflow).
2. New step parses `# build-platforms:` hint per app, default `linux/amd64,linux/arm64`.
3. `docker/build-push-action` receives the parsed `platforms:` input.
4. Resulting image manifest matches the hint.

## Error Handling

### Lint script

- All files checked before exit; engineer sees every violation at once instead of fixing-then-rediscovering.
- Each violation prints one line: `FAIL <path>: <specific reason>`. Examples:
  - `FAIL service-thesa/apps/default/Dockerfile: builder stage references ${TARGETARCH} but does not declare ARG TARGETARCH`
  - `FAIL <path>: builder FROM missing --platform=$BUILDPLATFORM`
  - `FAIL <path>: go build present without GOOS=${TARGETOS} GOARCH=${TARGETARCH} and no # build-platforms: opt-out`
- Final exit: 0 (clean) or 1 (any FAIL). SKIPs do not affect exit code.

### CI job

- Job name `dockerfile-lint` so failures show up clearly in PR status checks.
- `bash -e` on the run step so non-zero exit fails the job. No retry (deterministic).

### Opt-out edges

- `# build-platforms: linux/amd64` honored by both the lint script (SKIP) and `docker-release.yml` (build amd64-only). Same comment for both — engineer changes one line to opt out.
- Other values (e.g. `linux/amd64,linux/arm/v7`) honored: the script treats the line's *presence* as an opt-out from strict TARGETARCH checks; actual platforms still controlled by `docker-release.yml`.
- Malformed comment (e.g. typo `# build-platform:` singular) → lint applies normally and `docker-release.yml` ignores it. Fails closed.

### Builder workflow

The HINT-parsing step is a verbatim copy from `common/docker-release.yml`. If the regex ever diverges between the two workflows that's a bug; out of scope here but a candidate for a future iteration (e.g. extract HINT parsing into a shared action).

### Out of scope (explicit non-goals)

- Detecting arch-specific package installs (`apt-get install qemu-x86`) or downloads of arch-pinned binaries. Too fuzzy to lint reliably. Fixed manually if encountered.
- Validating that base images publish multi-arch manifests. Audit already confirmed all current bases (`cgr.dev/chainguard/static`, `alpine:3.19`, `ubuntu:22.04`, `golang:1.26`) do.
- Adding `make lint-dockerfiles` targets to each repo's Makefile.
- Auditing or modifying non-app Dockerfiles (`builder/Dockerfile.demo`, `builder/Dockerfile`) — neither is published by any release workflow.

## Testing

### Lint script validation (pre-merge, local)

Run `check-dockerfile-multiarch.sh` against each of the 10 repos locally. Expected results:

- All 10 repos exit 0.
- `service-thesa/apps/default/Dockerfile` → PASS (after fix).
- `service-files/apps/ocr/Dockerfile` → SKIP (amd64-only by design).
- `service-trustage/apps/{default,formstore,queue}/Dockerfile` → PASS (after cleanup).
- Remaining 38 → PASS.

False-negative sanity check: temporarily revert the service-thesa fix, confirm script reports `FAIL` with the expected reason, restore.

False-positive sanity check: nothing currently passing should newly fail. The audit established the 41 baseline-good files.

### Builder workflow patch validation

Run `actionlint` against the patched `builder/.github/workflows/release.yml`. Visually diff the new `platforms` step against `common/docker-release.yml` lines 48-59 — character-for-character match required (the `DOCKERFILE` variable name and `${{ matrix.app }}` reference).

No builder Dockerfile currently uses `# build-platforms:`, so only the default branch (`linux/amd64,linux/arm64`) is exercised at release time. Don't add a fake opt-out just to test — the parsing logic is a verbatim copy.

### Multi-arch image validation (post-merge, on next release tag)

After `service-thesa` cuts its next release:

- `docker buildx imagetools inspect ghcr.io/antinvestor/service-thesa:<tag>` must show both `linux/amd64` and `linux/arm64`.
- `docker run --platform=linux/arm64 ghcr.io/antinvestor/service-thesa:<tag> --version` should succeed on an arm64 host (or via QEMU) — pre-fix it would fail with `exec format error` because the arm64 manifest contained an amd64 binary.

This is the only test that proves the silent bug is actually fixed. Worth doing once.

### CI integration validation

After wiring `dockerfile-lint` into one repo's `ci.yaml`, open a no-op PR there and confirm the job runs and passes. Then roll out to the remaining 9.

Then deliberately open a PR that breaks a Dockerfile (e.g. delete `ARG TARGETARCH`); confirm the job fails with the expected message; close the PR.

### Out of scope (explicit non-tests)

- No unit tests for the bash script. ~60 lines of grep glue; integration testing against the 44 real Dockerfiles is the better signal.
- No load/performance testing. Lint runs in <2s per repo.

## Acceptance Criteria

- [ ] `service-thesa/apps/default/Dockerfile` declares `ARG TARGETOS` and `ARG TARGETARCH` inside the builder stage.
- [ ] `service-trustage/apps/{default,formstore,queue}/Dockerfile` have no dead top-level `ARG TARGETOS` / `ARG TARGETARCH` lines.
- [ ] `builder/.github/workflows/release.yml` parses `# build-platforms:` hints and uses the parsed value for `docker/build-push-action`'s `platforms:` input.
- [ ] `common/scripts/check-dockerfile-multiarch.sh` exists, exits 0 against all 10 repos with the fixes above applied.
- [ ] `common/.github/workflows/dockerfile-lint.yml` exists, callable via `workflow_call`.
- [ ] All 10 repos' `ci.yaml` include a `dockerfile-lint:` job calling the common workflow.
- [ ] Next `service-thesa` release produces an arm64 manifest containing an arm64 binary (verified via `imagetools inspect` and a `--platform=linux/arm64` run).

## Rollout Order

1. Land `common/scripts/check-dockerfile-multiarch.sh` and `common/.github/workflows/dockerfile-lint.yml` in `common` (single PR).
2. Land the 5 Dockerfile/workflow fixes, each in its own repo PR. Each fix-PR is small enough to land independently.
3. Land the CI wiring in each repo (one PR per repo, mechanical change).
4. Verify the next `service-thesa` release produces a correct arm64 manifest.

Step 2 and step 3 can be interleaved per repo; the lint workflow won't fail any of the 10 already-correct repos.
