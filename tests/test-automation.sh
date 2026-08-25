#!/usr/bin/env sh
set -u

# shellcheck source=tests/testlib.sh
. "$(dirname "$0")/testlib.sh"

CLI="$TEST_ROOT/system/bin/bluefilter"
CORE="$TEST_ROOT/system/bin/bluefilter-core"
MOCKS="$TEST_ROOT/tests/mocks"
# shellcheck disable=SC1090
. "$CORE"

setup_automation() {
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
        BLUEFILTER_DAEMON="$MOCKS/bluefilter-daemon" \
        BLUEFILTER_NOW_HHMM="${TEST_NOW:-}" \
        sh "$CLI" "$@" 2>&1)
    RUN_STATUS=$?
}

enable_schedule_directly() {
    config_set "$TEST_MODDIR/config.conf" schedule enabled 1
}

test_cross_midnight_schedule_owns_then_releases_state() {
    setup_automation
    enable_schedule_directly
    TEST_NOW=2300 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/enabled" || return 1
    assert_eq 'schedule' "$(state_get "$TEST_MODDIR/enabled" source)" || return 1
    assert_file_exists "$TEST_MODDIR/.auto_enabled" || return 1
    TEST_NOW=0700 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/enabled"
}

test_manual_on_survives_sunrise() {
    setup_automation
    enable_schedule_directly
    run_bluefilter on red-dim
    assert_success "$RUN_STATUS" || return 1
    TEST_NOW=0700 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/enabled" || return 1
    assert_eq 'manual' "$(state_get "$TEST_MODDIR/enabled" source)"
}

test_manual_off_suppresses_same_night_reenable() {
    setup_automation
    enable_schedule_directly
    TEST_NOW=2300 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    run_bluefilter off
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/.manual_off" || return 1
    TEST_NOW=2310 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/enabled"
}

test_daytime_clears_manual_override_for_next_night() {
    setup_automation
    enable_schedule_directly
    TEST_NOW=2300 run_bluefilter schedule evaluate
    run_bluefilter off
    TEST_NOW=1200 run_bluefilter schedule evaluate
    assert_file_missing "$TEST_MODDIR/.manual_off" || return 1
    TEST_NOW=2300 run_bluefilter schedule evaluate
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/enabled"
}

test_same_day_window_and_equal_time_rejection() {
    setup_automation
    config_set "$TEST_MODDIR/config.conf" schedule enabled 1
    config_set "$TEST_MODDIR/config.conf" schedule sunset 06:00
    config_set "$TEST_MODDIR/config.conf" schedule sunrise 21:00
    TEST_NOW=1200 run_bluefilter schedule evaluate
    assert_file_exists "$TEST_MODDIR/enabled" || return 1
    run_bluefilter schedule set 06:00 06:00
    assert_eq '2' "$RUN_STATUS"
}

test_no_features_means_no_daemon() {
    setup_automation
    printf '999999\n' > "$TEST_MODDIR/daemon.pid"
    run_bluefilter daemon-reconcile
    assert_success "$RUN_STATUS" || return 1
    assert_file_missing "$TEST_MODDIR/daemon.pid" || return 1
    assert_contains "$RUN_OUTPUT" 'stopped'
}

test_service_has_bounded_readiness_and_no_fixed_delay() {
    service=$(cat "$TEST_ROOT/service.sh")
    assert_contains "$service" 'check SurfaceFlinger' || return 1
    assert_contains "$service" 'attempt" -lt 60' || return 1
    case "$service" in *'sleep 5'*) return 1 ;; esac
}

test_daemon_exits_when_no_feature_requires_it() {
    setup_automation
    BLUEFILTER_TESTING=1 \
        BLUEFILTER_MODDIR="$TEST_MODDIR" \
        BLUEFILTER_CORE="$CORE" \
        BLUEFILTER_CLI="$CLI" \
        BLUEFILTER_CMD="$MOCKS/cmd" \
        BLUEFILTER_ONCE=1 \
        timeout 3 sh "$TEST_ROOT/system/bin/bluefilter-daemon" >/dev/null 2>&1
    status=$?
    assert_success "$status" || return 1
    assert_file_missing "$TEST_MODDIR/daemon.pid"
}

test_disabling_schedule_converts_active_state_to_manual() {
    setup_automation
    enable_schedule_directly
    TEST_NOW=2300 run_bluefilter schedule evaluate
    assert_eq 'schedule' "$(state_get "$TEST_MODDIR/enabled" source)" || return 1
    run_bluefilter schedule off
    assert_success "$RUN_STATUS" || return 1
    assert_file_exists "$TEST_MODDIR/enabled" || return 1
    assert_eq 'manual' "$(state_get "$TEST_MODDIR/enabled" source)" || return 1
    assert_file_missing "$TEST_MODDIR/.auto_enabled"
}

for test_name in \
    test_cross_midnight_schedule_owns_then_releases_state \
    test_manual_on_survives_sunrise \
    test_manual_off_suppresses_same_night_reenable \
    test_daytime_clears_manual_override_for_next_night \
    test_same_day_window_and_equal_time_rejection \
    test_no_features_means_no_daemon \
    test_service_has_bounded_readiness_and_no_fixed_delay \
    test_daemon_exits_when_no_feature_requires_it \
    test_disabling_schedule_converts_active_state_to_manual
do
    run_test "$test_name"
done

finish_tests
