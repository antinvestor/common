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
run_case "missing-goos"     1 'FAIL.*GOOS=\$\{TARGETOS\}.*GOARCH=\$\{TARGETARCH\}'

if [[ "$failures" -gt 0 ]]; then
    echo "$failures test case(s) failed"
    exit 1
fi
echo "All test cases passed"
