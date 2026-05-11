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

    if [[ "$refs_targetarch" -gt 0 ]] && ! grep -qE '^[[:space:]]*ARG[[:space:]]+TARGETARCH' "$file"; then
        echo "FAIL $file: builder stage references \${TARGETARCH} but does not declare ARG TARGETARCH"
        failures=$((failures + 1))
        return 1
    fi

    if [[ "$refs_targetos" -gt 0 ]] && ! grep -qE '^[[:space:]]*ARG[[:space:]]+TARGETOS' "$file"; then
        echo "FAIL $file: builder stage references \${TARGETOS} but does not declare ARG TARGETOS"
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
