#!/usr/bin/env sh
set -u

# shellcheck source=tests/testlib.sh
. "$(dirname "$0")/testlib.sh"
CORE="$TEST_ROOT/system/bin/bluefilter-core"

if [ ! -r "$CORE" ]; then
    printf 'Missing shared core: %s\n' "$CORE" >&2
    exit 1
fi
# shellcheck disable=SC1090
. "$CORE"

test_red_matrix_is_column_major() {
    expected='0.2126 0 0 0 0.7152 0 0 0 0.0722 0 0 0 0 0 0 1'
    assert_eq "$expected" "$(profile_matrix red)"
}

test_red_matrix_preserves_green_luminance() {
    matrix=$(profile_matrix red)
    # shellcheck disable=SC2086
    set -- $matrix
    assert_eq '0.7152' "$5"
}

test_profile_defaults_are_ordered() {
    assert_eq '1.00' "$(profile_default_brightness red)" || return 1
    assert_eq '0.55' "$(profile_default_brightness red-dim)" || return 1
    assert_eq '0.30' "$(profile_default_brightness red-extra-dim)"
}

test_matrix_brightness_scales_color_only() {
    scaled=$(scale_matrix "$(profile_matrix red)" 0.5)
    # shellcheck disable=SC2086
    set -- $scaled
    assert_eq '0.1063' "$1" || return 1
    assert_eq '0.3576' "$5" || return 1
    assert_eq '1' "${16}"
}

test_rejects_black_custom_matrix() {
    assert_failure validate_matrix '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1'
}

test_rejects_translation_and_negative_coefficients() {
    assert_failure validate_matrix '1 0 0 0 0 1 0 0 0 0 1 0 0.1 0 0 1' || return 1
    assert_failure validate_matrix '-1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1'
}

test_accepts_safe_luminance_matrix() {
    validate_matrix "$(profile_matrix red)"
}

test_rgb_migration_builds_diagonal_matrix() {
    expected='0.8 0 0 0 0 0.3 0 0 0 0 0.1 0 0 0 0 1'
    assert_eq "$expected" "$(rgb_to_matrix '0.8 0.3 0.1')"
}

test_config_reader_is_section_aware() {
    fixture=$TEST_ROOT/tests/fixtures/config-v1.conf
    assert_eq 'custom' "$(config_get "$fixture" default profile)" || return 1
    assert_eq '21:00' "$(config_get "$fixture" schedule sunset)"
}

test_config_writer_is_atomic_and_adds_missing_key() {
    temp_dir=$(mktemp -d)
    cp "$TEST_ROOT/tests/fixtures/config-v1.conf" "$temp_dir/config.conf"
    config_set "$temp_dir/config.conf" default brightness 0.55 || return 1
    assert_eq '0.55' "$(config_get "$temp_dir/config.conf" default brightness)" || return 1
    [ ! -e "$temp_dir/config.conf.tmp.$$" ]
}

test_time_validation_and_night_windows() {
    validate_time '21:05' || return 1
    assert_failure validate_time '24:00' || return 1
    assert_failure validate_time '9:00' || return 1
    is_night_window 2300 2100 0600 || return 1
    is_night_window 0300 2100 0600 || return 1
    assert_failure is_night_window 1200 2100 0600 || return 1
    is_night_window 1200 0600 2100 || return 1
    assert_failure is_night_window 1200 0600 0600
}

test_migration_completes_missing_v1_sections() {
    temp_dir=$(mktemp -d)
    cat > "$temp_dir/config.conf" <<'CONF'
[profiles]
custom=0.8 0.3 0.1
[default]
profile=custom
CONF
    migrate_config "$temp_dir/config.conf" || return 1
    assert_eq '2' "$(config_get "$temp_dir/config.conf" meta schema)" || return 1
    assert_eq '0' "$(config_get "$temp_dir/config.conf" schedule enabled)" || return 1
    assert_eq '21:00' "$(config_get "$temp_dir/config.conf" schedule sunset)" || return 1
    assert_eq '0' "$(config_get "$temp_dir/config.conf" notification enabled)" || return 1
    config_is_valid "$temp_dir/config.conf"
}

test_config_validation_rejects_malformed_v2() {
    config_is_valid "$TEST_ROOT/tests/fixtures/config-v2.conf" || return 1
    assert_failure config_is_valid "$TEST_ROOT/tests/fixtures/config-invalid.conf"
}

test_config_writer_rejects_embedded_newlines() {
    temp_dir=$(mktemp -d)
    cp "$TEST_ROOT/tests/fixtures/config-v2.conf" "$temp_dir/config.conf"
    newline_value=$(printf 'red-dim\nnotification=1')
    assert_failure config_set "$temp_dir/config.conf" default profile "$newline_value"
}

for test_name in \
    test_red_matrix_is_column_major \
    test_red_matrix_preserves_green_luminance \
    test_profile_defaults_are_ordered \
    test_matrix_brightness_scales_color_only \
    test_rejects_black_custom_matrix \
    test_rejects_translation_and_negative_coefficients \
    test_accepts_safe_luminance_matrix \
    test_rgb_migration_builds_diagonal_matrix \
    test_config_reader_is_section_aware \
    test_config_writer_is_atomic_and_adds_missing_key \
    test_time_validation_and_night_windows \
    test_migration_completes_missing_v1_sections \
    test_config_validation_rejects_malformed_v2 \
    test_config_writer_rejects_embedded_newlines
do
    run_test "$test_name"
done

finish_tests
