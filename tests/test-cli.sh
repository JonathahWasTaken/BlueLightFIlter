#!/usr/bin/env sh
set -u

# shellcheck source=tests/testlib.sh
. "$(dirname "$0")/testlib.sh"

CLI="$TEST_ROOT/system/bin/bluefilter"
CORE="$TEST_ROOT/system/bin/bluefilter-core"
MOCKS="$TEST_ROOT/tests/mocks"

setup_cli() {
    TEST_MODDIR=$(mktemp -d)
    export TEST_MODDIR
    cp "$TEST_ROOT/tests/fixtures/config-v2.conf" "$TEST_MODDIR/config.conf"
    MOCK_SERVICE_LOG="$TEST_MODDIR/service.log"
    MOCK_SERVICE_FAIL_FILE="$TEST_MODDIR/service.fail"
    export MOCK_SERVICE_LOG MOCK_SERVICE_FAIL_FILE
    : > "$MOCK_SERVICE_LOG"
    RUN_OUTPUT=
    RUN_STATUS=0
}

run_bluefilter() {
    RUN_OUTPUT=$(BLUEFILTER_TESTING=1 \
        BLUEFILTER_MODDIR="$TEST_MODDIR" \
        BLUEFILTER_CORE="$CORE" \
        BLUEFILTER_SERVICE="$MOCKS/service" \
        BLUEFILTER_GETPROP="$MOCKS/getprop" \
        BLUEFILTER_SETTINGS="$MOCKS/settings" \
        sh "$CLI" "$@" 2>&1)
    RUN_STATUS=$?
}

test_on_and_off_are_idempotent() {
    setup_cli
    run_bluefilter on red-dim
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/enabled" || return 1
    run_bluefilter on red-dim
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter off
    assert_success "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/enabled" || return 1
    run_bluefilter off
    assert_success "$RUN_STATUS"
}

test_toggle_is_deterministic() {
    setup_cli
    run_bluefilter toggle red-dim
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter is-on
    assert_success "$RUN_STATUS" || return 1
    assert_eq '' "$RUN_OUTPUT" || return 1
    run_bluefilter toggle red-dim
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter is-on
    assert_eq '1' "$RUN_STATUS" || return 1
    assert_eq '' "$RUN_OUTPUT"
}

test_reset_ignores_malformed_config() {
    setup_cli
    cp "$TEST_ROOT/tests/fixtures/config-invalid.conf" "$TEST_MODDIR/config.conf"
    : > "$TEST_MODDIR/enabled"
    run_bluefilter reset
    assert_success "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/enabled" || return 1
    service_log=$(cat "$MOCK_SERVICE_LOG")
    assert_contains "$service_log" 'call SurfaceFlinger 1015 i32 1 f 1 f 0 f 0 f 0'
}

test_status_json_has_stable_contract() {
    setup_cli
    run_bluefilter on red-dim
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter status --json
    assert_success "$RUN_STATUS" || return 1
    assert_contains "$RUN_OUTPUT" '"enabled":true' || return 1
    assert_contains "$RUN_OUTPUT" '"profile":"red-dim"' || return 1
    assert_contains "$RUN_OUTPUT" '"brightness":0.55' || return 1
    assert_contains "$RUN_OUTPUT" '"source":"manual"'
}

test_profile_set_and_brightness_reapply() {
    setup_cli
    run_bluefilter profile set red
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter profile get
    assert_eq 'red' "$RUN_OUTPUT" || return 1
    run_bluefilter on
    assert_success "$RUN_STATUS" || return 1
    : > "$MOCK_SERVICE_LOG"
    run_bluefilter brightness 0.50
    assert_success "$RUN_STATUS" || return 1
    assert_contains "$(cat "$MOCK_SERVICE_LOG")" 'f 0.1063'
}

test_invalid_profile_never_calls_surfaceflinger() {
    setup_cli
    run_bluefilter on '../../system/bin/sh'
    assert_eq '2' "$RUN_STATUS" || return 1
    assert_eq '' "$(cat "$MOCK_SERVICE_LOG")"
}

test_failed_surfaceflinger_call_does_not_write_state() {
    setup_cli
    : > "$MOCK_SERVICE_FAIL_FILE"
    run_bluefilter on red
    assert_eq '3' "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/enabled"
}

test_compatibility_aliases_and_predicates() {
    setup_cli
    run_bluefilter start amber
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter current
    assert_eq 'amber' "$RUN_OUTPUT" || return 1
    run_bluefilter status --quiet
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter stop
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter status --quiet
    assert_eq '1' "$RUN_STATUS"
}

test_invalid_stored_custom_matrix_is_not_selected() {
    setup_cli
    # shellcheck source=system/bin/bluefilter-core
    . "$CORE"
    config_set "$TEST_MODDIR/config.conf" custom matrix '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1'
    run_bluefilter on custom
    assert_eq '2' "$RUN_STATUS" || return 1
    profile=$(awk '/^\[default\]/{s=1;next}/^\[/{s=0}s&&/^profile=/{sub(/^profile=/,"");print;exit}' "$TEST_MODDIR/config.conf")
    assert_eq 'red-dim' "$profile" || return 1
    assert_file_missing "$TEST_MODDIR/enabled"
}

test_brightness_rejects_combined_near_black_matrix() {
    setup_cli
    # shellcheck source=system/bin/bluefilter-core
    . "$CORE"
    config_set "$TEST_MODDIR/config.conf" custom matrix '0.1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1'
    config_set "$TEST_MODDIR/config.conf" default profile custom
    config_set "$TEST_MODDIR/config.conf" default brightness 1.00
    run_bluefilter brightness 0.10
    assert_eq '2' "$RUN_STATUS" || return 1
    assert_eq '1.00' "$(config_get "$TEST_MODDIR/config.conf" default brightness)"
}

for test_name in \
    test_on_and_off_are_idempotent \
    test_toggle_is_deterministic \
    test_reset_ignores_malformed_config \
    test_status_json_has_stable_contract \
    test_profile_set_and_brightness_reapply \
    test_invalid_profile_never_calls_surfaceflinger \
    test_failed_surfaceflinger_call_does_not_write_state \
    test_compatibility_aliases_and_predicates \
    test_invalid_stored_custom_matrix_is_not_selected \
    test_brightness_rejects_combined_near_black_matrix
do
    run_test "$test_name"
done

finish_tests
