#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN="$PROJECT_DIR/macnotifier.app/Contents/MacOS/macnotifier"

if [ ! -x "$BIN" ]; then
    echo "Error: binary not found at $BIN (run build first)"
    exit 1
fi

passed=0
failed=0

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2

    set +e
    "$BIN" "$@" >/dev/null 2>&1
    local actual_exit=$?
    set -e

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        failed=$((failed + 1))
    fi
}

run_test_output() {
    local name="$1"
    local expected_exit="$2"
    local expected_pattern="$3"
    shift 3

    set +e
    local output
    output=$("$BIN" "$@" 2>&1)
    local actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        failed=$((failed + 1))
        return
    fi

    if echo "$output" | grep -qi -- "$expected_pattern"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (output missing '$expected_pattern')"
        failed=$((failed + 1))
    fi
}

# Test: -h shows usage and exits 0
run_test_output "-h shows help and exits 0" 0 "Usage" -h

# Test: missing -m exits 1
run_test_output "missing -m exits 1" 1 "required"

# Test: unknown option exits 1
run_test_output "unknown option exits 1" 1 "unknown" --unknown-flag

# Test: -m without value exits 1
run_test "-m without value exits 1" 1 -m

# Test: --sound without value exits 1
run_test "--sound without value exits 1" 1 -m "test" --sound

# Test: --icon without value exits 1
run_test "--icon without value exits 1" 1 -m "test" --icon

# Test: -h shows --sound option
run_test_output "-h shows --sound option" 0 "--sound" -h

# Test: -h shows --icon option
run_test_output "-h shows --icon option" 0 "--icon" -h

# CLI wrapper tests
WRAPPER="$PROJECT_DIR/bin/macnotifier"

run_wrapper_test() {
    local name="$1"
    local expected_exit="$2"
    local expected_pattern="$3"
    shift 3

    set +e
    local output
    output=$("$WRAPPER" "$@" 2>&1)
    local actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        failed=$((failed + 1))
        return
    fi

    if echo "$output" | grep -qi -- "$expected_pattern"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (output missing '$expected_pattern')"
        failed=$((failed + 1))
    fi
}

if [ ! -x "$WRAPPER" ]; then
    echo "FAIL: CLI wrapper not found or not executable at $WRAPPER"
    failed=$((failed + 1))
else
    echo "PASS: CLI wrapper exists and is executable"
    passed=$((passed + 1))

    # Test: wrapper -h shows usage with "Usage" in output
    run_wrapper_test "wrapper -h shows help" 0 "Usage" -h

    # Test: wrapper without -m shows error
    run_wrapper_test "wrapper missing -m exits 1" 1 "required"
fi

echo ""
echo "Results: $passed passed, $failed failed"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
