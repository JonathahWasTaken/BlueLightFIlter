#!/usr/bin/env sh
set -u

# shellcheck source=tests/testlib.sh
. "$(dirname "$0")/testlib.sh"
WEBUI="$TEST_ROOT/webroot/index.html"
CONTENT=$(cat "$WEBUI")

test_webui_uses_cli_as_only_mutation_boundary() {
    assert_contains "$CONTENT" 'bluefilter status --json' || return 1
    # These are literal JavaScript injection markers.
    # shellcheck disable=SC2016
    case "$CONTENT" in
        *'service call SurfaceFlinger'*|*'sed -i'*|*'touch ${'*|*'rm -f ${'*) return 1 ;;
    esac
}

test_webui_has_accessible_runtime_states() {
    assert_contains "$CONTENT" 'id="loading-state"' || return 1
    assert_contains "$CONTENT" 'id="error-state"' || return 1
    assert_contains "$CONTENT" 'aria-live="polite"' || return 1
    assert_contains "$CONTENT" 'class="skip-link"' || return 1
    assert_contains "$CONTENT" ':focus-visible' || return 1
    assert_contains "$CONTENT" 'prefers-reduced-motion'
}

test_webui_exposes_profiles_brightness_and_custom_matrix() {
    for value in warm amber deep-red red red-dim red-extra-dim custom; do
        assert_contains "$CONTENT" "data-profile=\"$value\"" || return 1
    done
    assert_contains "$CONTENT" 'id="brightness"' || return 1
    assert_contains "$CONTENT" 'bluefilter matrix set' || return 1
    assert_contains "$CONTENT" 'bluefilter matrix get'
}

test_webui_exposes_all_automation_controls() {
    assert_contains "$CONTENT" 'bluefilter autoboot' || return 1
    assert_contains "$CONTENT" 'bluefilter schedule' || return 1
    assert_contains "$CONTENT" 'bluefilter notification' || return 1
    assert_contains "$CONTENT" 'bluefilter reset'
}

test_webui_avoids_high_frequency_shell_polling_and_emoji() {
    case "$CONTENT" in *'setInterval('*|*'🌙'*|*'✅'*|*'⚙'*|*'✖'*) return 1 ;; esac
}

test_webui_has_responsive_and_touch_safety_rules() {
    assert_contains "$CONTENT" 'min-height: 48px' || return 1
    assert_contains "$CONTENT" 'env(safe-area-inset-bottom)' || return 1
    assert_contains "$CONTENT" '@media (min-width: 768px)' || return 1
    assert_contains "$CONTENT" 'min-height: 100dvh'
}

for test_name in \
    test_webui_uses_cli_as_only_mutation_boundary \
    test_webui_has_accessible_runtime_states \
    test_webui_exposes_profiles_brightness_and_custom_matrix \
    test_webui_exposes_all_automation_controls \
    test_webui_avoids_high_frequency_shell_polling_and_emoji \
    test_webui_has_responsive_and_touch_safety_rules
do
    run_test "$test_name"
done

finish_tests
