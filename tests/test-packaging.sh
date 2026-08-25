#!/usr/bin/env sh
set -u

# shellcheck source=tests/testlib.sh
. "$(dirname "$0")/testlib.sh"

CLI="$TEST_ROOT/system/bin/bluefilter"
CORE="$TEST_ROOT/system/bin/bluefilter-core"
MOCKS="$TEST_ROOT/tests/mocks"

setup_packaging() {
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

test_uses_official_magisk_installer_entrypoint() {
    installer=$(cat "$TEST_ROOT/META-INF/com/google/android/update-binary")
    assert_contains "$installer" 'install_module' || return 1
    assert_contains "$installer" 'util_functions.sh'
}

test_schema_metadata_and_core_permissions_are_current() {
    config=$(cat "$TEST_ROOT/config.conf")
    metadata=$(cat "$TEST_ROOT/module.prop")
    customize=$(cat "$TEST_ROOT/customize.sh")
    assert_contains "$config" 'schema=2' || return 1
    assert_contains "$config" '[custom]' || return 1
    assert_contains "$metadata" 'version=2.0.1' || return 1
    assert_contains "$metadata" 'versionCode=20001' || return 1
    assert_contains "$customize" 'bluefilter-core' || return 1
    case "$customize" in *'SKIPUNZIP=1'*) return 1 ;; esac
}

test_shipped_runtime_files_use_lf_only() {
    for relative_path in \
        customize.sh \
        service.sh \
        action.sh \
        META-INF/com/google/android/update-binary \
        META-INF/com/google/android/updater-script \
        system/bin/bluefilter \
        system/bin/bluefilter-core \
        system/bin/bluefilter-daemon \
        config.conf \
        module.prop
    do
        byte_count=$(wc -c < "$TEST_ROOT/$relative_path")
        lf_byte_count=$(tr -d '\r' < "$TEST_ROOT/$relative_path" | wc -c)
        if [ "$byte_count" -ne "$lf_byte_count" ]; then
            printf '    CRLF bytes found in shipped file: %s\n' "$relative_path"
            return 1
        fi
    done
}

test_diag_reports_required_environment_and_conflicts() {
    setup_packaging
    run_bluefilter diag
    assert_success "$RUN_STATUS" || return 1
    assert_contains "$RUN_OUTPUT" 'Android: 15 (API 35)' || return 1
    assert_contains "$RUN_OUTPUT" 'Device: OnePlus CPH2583' || return 1
    assert_contains "$RUN_OUTPUT" 'SurfaceFlinger transaction: 1015' || return 1
    assert_contains "$RUN_OUTPUT" 'Configuration: valid (schema 2)' || return 1
    assert_contains "$RUN_OUTPUT" 'night_display_activated=0' || return 1
    assert_contains "$RUN_OUTPUT" 'compositor matrix cannot be read'
}

test_diag_test_restores_active_matrix() {
    setup_packaging
    run_bluefilter on red
    assert_success "$RUN_STATUS" || return 1
    : > "$MOCK_SERVICE_LOG"
    run_bluefilter diag --test
    assert_success "$RUN_STATUS" || return 1
    calls=$(grep '^call SurfaceFlinger' "$MOCK_SERVICE_LOG")
    assert_contains "$calls" 'f 0.1063' || return 1
    assert_contains "$calls" 'f 0.2126' || return 1
    assert_contains "$RUN_OUTPUT" 'active module matrix restored'
}

test_diag_test_skips_when_inactive() {
    setup_packaging
    run_bluefilter diag --test
    assert_success "$RUN_STATUS" || return 1
    calls=$(grep '^call SurfaceFlinger' "$MOCK_SERVICE_LOG" 2>/dev/null || true)
    assert_eq '' "$calls" || return 1
    assert_contains "$RUN_OUTPUT" 'skipped (inactive'
}

test_diag_test_has_trap_based_restoration() {
    cli=$(cat "$CLI")
    assert_contains "$cli" 'DIAG_RESTORE_MATRIX' || return 1
    assert_contains "$cli" 'restore_diag_matrix' || return 1
    # The dollar signs are intentional literals from the CLI source.
    # shellcheck disable=SC2016
    restore_line=$(grep -n 'DIAG_RESTORE_MATRIX=$original' "$CLI" | head -n 1 | cut -d: -f1)
    # shellcheck disable=SC2016
    apply_line=$(grep -n 'surfaceflinger_apply "$test_matrix"' "$CLI" | head -n 1 | cut -d: -f1)
    [ "$restore_line" -lt "$apply_line" ] || {
        printf '    restoration trap must be armed before applying the test matrix\n'
        return 1
    }
}

for test_name in \
    test_uses_official_magisk_installer_entrypoint \
    test_schema_metadata_and_core_permissions_are_current \
    test_shipped_runtime_files_use_lf_only \
    test_diag_reports_required_environment_and_conflicts \
    test_diag_test_restores_active_matrix \
    test_diag_test_skips_when_inactive \
    test_diag_test_has_trap_based_restoration
do
    run_test "$test_name"
done

finish_tests
