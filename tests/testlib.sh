#!/usr/bin/env sh

# Consumed by each test file that sources this harness.
# shellcheck disable=SC2034
TEST_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TEST_PASS=0
TEST_FAIL=0

assert_eq() {
    expected=$1
    actual=$2
    message=${3:-"expected '$expected', got '$actual'"}
    if [ "$expected" != "$actual" ]; then
        printf '    %s\n' "$message" >&2
        return 1
    fi
}

assert_success() {
    status=$1
    [ "$status" -eq 0 ] || {
        printf '    expected success, got status %s\n' "$status" >&2
        return 1
    }
}

assert_failure() {
    "$@" >/dev/null 2>&1
    status=$?
    [ "$status" -ne 0 ] || {
        printf '    expected failure: %s\n' "$*" >&2
        return 1
    }
}

assert_contains() {
    haystack=$1
    needle=$2
    case "$haystack" in
        *"$needle"*) return 0 ;;
    esac
    printf "    expected output to contain '%s'\n" "$needle" >&2
    return 1
}

assert_file_exists() {
    [ -f "$1" ] || {
        printf '    expected file: %s\n' "$1" >&2
        return 1
    }
}

assert_file_missing() {
    [ ! -e "$1" ] || {
        printf '    expected path to be absent: %s\n' "$1" >&2
        return 1
    }
}

run_test() {
    test_name=$1
    if "$test_name"; then
        TEST_PASS=$((TEST_PASS + 1))
        printf '  PASS %s\n' "$test_name"
    else
        TEST_FAIL=$((TEST_FAIL + 1))
        printf '  FAIL %s\n' "$test_name" >&2
    fi
}

finish_tests() {
    printf '%s passed, %s failed\n' "$TEST_PASS" "$TEST_FAIL"
    [ "$TEST_FAIL" -eq 0 ]
}
