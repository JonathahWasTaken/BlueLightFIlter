# BlueLightFIlter Production Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-optimized:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver a safe full-matrix compositor filter with stable automation CLI, conditional scheduling daemon, synchronized WebUI, robust installer, diagnostics, tests, and accurate documentation.

**Architecture:** A shared POSIX-shell core owns pure parsing, validation, matrix, state, and scheduling behavior. The public CLI is the only mutating interface used by humans, automations, boot, daemon, and WebUI. SurfaceFlinger transaction 1015 remains the small compositor backend with explicit last-writer conflict limitations.

**Tech Stack:** Android `/system/bin/sh`, AOSP `service`, dependency-free Bash test harness, plain HTML/CSS/JavaScript WebUI, official Magisk module installer.

**Assumptions:** Transaction 1015 exists on AOSP Android 8–16 — vendor ROMs may block or patch it. Root Binder access is available — state cannot prove visual application because the `service` CLI ignores Binder status. KernelSU exposes standard Magisk-compatible module helpers — APatch remains unverified.

---

## File structure

- Create `system/bin/bluefilter-core`: shared pure helpers and state/config primitives.
- Replace `system/bin/bluefilter`: public CLI, SurfaceFlinger adapter, diagnostics, process lifecycle.
- Replace `system/bin/bluefilter-daemon`: thin conditional scheduler/notification loop.
- Replace `service.sh`: bounded readiness, autoboot, daemon reconciliation.
- Modify `customize.sh`, `config.conf`, `module.prop`, `META-INF/.../update-binary`: packaging and migration.
- Replace `webroot/index.html`: accessible CLI-backed control panel.
- Create `tests/testlib.sh`, `tests/run-tests.sh`, `tests/test-core.sh`, `tests/test-cli.sh`, `tests/test-automation.sh`, `tests/test-webui.sh`, `tests/mocks/*`: dependency-free validation.
- Replace `README.md`: production documentation.

### Task 1: Establish test harness and matrix/config contract

**Files:**
- Create: `tests/testlib.sh`
- Create: `tests/run-tests.sh`
- Create: `tests/test-core.sh`
- Create: `tests/fixtures/config-v1.conf`
- Create: `tests/fixtures/config-invalid.conf`
- Test: `system/bin/bluefilter-core`

**Does NOT cover:** device Binder execution or vendor ROM behavior.

- [x] **Step 1: Write failing core tests**

```sh
test_red_matrix_column_major() {
  assert_eq "0.2126 0 0 0 0.7152 0 0 0 0.0722 0 0 0 0 0 0 1" "$(profile_matrix red)"
}
test_reject_black_custom_matrix() {
  assert_failure validate_matrix "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1"
}
test_migrate_rgb_custom() {
  assert_eq "0.8 0 0 0 0 0.3 0 0 0 0 0.1 0 0 0 0 1" "$(rgb_to_matrix '0.8 0.3 0.1')"
}
```

- [x] **Step 2: Verify RED**

Run: `rtk proxy sh tests/run-tests.sh core`  
Expected: FAIL because `system/bin/bluefilter-core` does not exist.

- [x] **Step 3: Implement shared core**

Implement strict decimal/time/profile validation, built-in column-major matrices, brightness scaling, safe section/key parsing, same-directory atomic writes, schema migration helpers, state records, JSON-safe validated output, directory locking, and `is_night_window`.

- [x] **Step 4: Verify GREEN**

Run: `rtk proxy sh tests/run-tests.sh core`  
Expected: all core tests pass.

### Task 2: Build stable public CLI and recovery behavior

**Files:**
- Create: `tests/test-cli.sh`
- Create: `tests/mocks/service`
- Create: `tests/mocks/getprop`
- Create: `tests/mocks/settings`
- Modify: `system/bin/bluefilter`

**Does NOT cover:** reading the actual compositor matrix; AOSP exposes no transaction-1015 getter.

- [x] **Step 1: Write failing CLI tests**

```sh
test_toggle_is_deterministic() {
  run_bluefilter toggle red-dim; assert_success
  run_bluefilter is-on; assert_success
  run_bluefilter toggle red-dim; assert_success
  run_bluefilter is-on; assert_status 1
}
test_reset_ignores_bad_config() {
  cp tests/fixtures/config-invalid.conf "$TEST_MODDIR/config.conf"
  run_bluefilter reset
  assert_success
  assert_file_contains "$MOCK_SERVICE_LOG" "f 1 f 0 f 0 f 0"
}
test_status_json_contract() {
  run_bluefilter on red-dim
  run_bluefilter status --json
  assert_output_contains '"enabled":true'
  assert_output_contains '"profile":"red-dim"'
}
```

- [x] **Step 2: Verify RED**

Run: `rtk proxy sh tests/run-tests.sh cli`  
Expected: FAIL on missing commands and JSON contract.

- [x] **Step 3: Implement CLI**

Add `on`, `off`, `toggle`, `is-on`, `current`, status modes, profile commands, `apply`, brightness, autoboot, schedule, notification, daemon commands, compatibility aliases, stable exit codes, stderr errors, lock use, and config-independent reset. Apply matrices only after full validation. Write state only after the local SurfaceFlinger command succeeds.

- [x] **Step 4: Verify GREEN**

Run: `rtk proxy sh tests/run-tests.sh cli`  
Expected: all CLI tests pass.

### Task 3: Serialize scheduling and make the daemon conditional

**Files:**
- Create: `tests/test-automation.sh`
- Create: `tests/mocks/cmd`
- Modify: `system/bin/bluefilter-daemon`
- Modify: `service.sh`

**Does NOT cover:** exact alarm delivery without polling or notification APIs absent from a vendor ROM.

- [x] **Step 1: Write failing automation tests**

```sh
test_manual_on_survives_sunrise() {
  seed_enabled manual red-dim
  evaluate_schedule 0700 2100 0600
  assert_file_exists "$TEST_MODDIR/enabled"
}
test_manual_off_suppresses_same_night_reenable() {
  seed_enabled schedule red-dim
  run_bluefilter off
  evaluate_schedule 2300 2100 0600
  assert_file_missing "$TEST_MODDIR/enabled"
}
test_no_features_means_no_daemon() {
  set_feature schedule 0; set_feature notification 0
  run_bluefilter daemon-reconcile
  assert_file_missing "$TEST_MODDIR/daemon.pid"
}
```

- [x] **Step 2: Verify RED**

Run: `rtk proxy sh tests/run-tests.sh automation`  
Expected: FAIL because ownership/override/reconcile behavior is missing.

- [x] **Step 3: Implement automation state machine**

Use `source=manual|schedule|boot`, `.auto_enabled`, and `.manual_off`. Make the daemon exit when neither feature requires it. Reconcile on every feature setter and boot. Replace fixed boot sleep with bounded SurfaceFlinger readiness probes.

- [x] **Step 4: Verify GREEN**

Run: `rtk proxy sh tests/run-tests.sh automation`  
Expected: all schedule and lifecycle tests pass.

### Task 4: Rebuild WebUI around the CLI contract

**Files:**
- Create: `tests/test-webui.sh`
- Modify: `webroot/index.html`

**Does NOT cover:** a WebUI host that does not implement the documented `ksu.exec` bridge.

- [x] **Step 1: Write failing static/security tests**

```sh
assert_file_contains webroot/index.html 'bluefilter status --json'
assert_file_contains webroot/index.html 'aria-live="polite"'
assert_file_contains webroot/index.html 'prefers-reduced-motion'
assert_file_not_contains webroot/index.html 'service call SurfaceFlinger'
assert_file_not_contains webroot/index.html 'sed -i'
```

- [x] **Step 2: Verify RED**

Run: `rtk proxy sh tests/run-tests.sh webui`  
Expected: FAIL because current WebUI calls SurfaceFlinger and edits config directly.

- [x] **Step 3: Implement OLED minimal control panel**

Use fixed CLI commands, status JSON, allowlisted profile names, validated decimal/time input, pending/error/loading states, profile cards, brightness control, advanced custom matrix editor, automation controls, diagnostics/recovery actions, semantic markup, focus rings, 48 px targets, safe areas, reduced motion, and responsive layouts.

- [x] **Step 4: Verify GREEN and browser behavior**

Run: `rtk proxy sh tests/run-tests.sh webui`  
Expected: static/security tests pass. Then serve repository locally and verify 375/768/1024/1440 widths plus runtime logs with a mocked `ksu` bridge in the browser.

### Task 5: Fix packaging, migration, and diagnostics

**Files:**
- Create: `tests/test-packaging.sh`
- Modify: `META-INF/com/google/android/update-binary`
- Modify: `customize.sh`
- Modify: `config.conf`
- Modify: `module.prop`
- Modify: `action.sh`
- Modify: `system/bin/bluefilter`

**Does NOT cover:** claiming tested APatch compatibility or unsafe transform testing while the module is inactive.

- [x] **Step 1: Write failing packaging/diagnostic tests**

```sh
assert_file_contains META-INF/com/google/android/update-binary 'install_module'
assert_file_contains config.conf 'schema=2'
assert_file_contains module.prop 'version=2.0.0'
assert_diag_contains 'SurfaceFlinger transaction'
assert_diag_restores_active_matrix
```

- [x] **Step 2: Verify RED**

Run: `rtk proxy sh tests/run-tests.sh packaging`  
Expected: FAIL on installer, schema, version, and diagnostics.

- [x] **Step 3: Implement packaging and diagnostics**

Install the official Magisk module installer, rely on default extraction, set all script permissions, migrate v1 RGB config without sourcing it, preserve upgrade state, and add non-destructive diagnostics with conflict keys and safe `--test` restoration.

- [x] **Step 4: Verify GREEN**

Run: `rtk proxy sh tests/run-tests.sh packaging`  
Expected: all packaging and diagnostics tests pass.

### Task 6: Rewrite documentation and verify the complete module

**Files:**
- Modify: `README.md`
- Modify: `project-map.md`
- Create: `session-log.md`

- [x] **Step 1: Replace README**

Document architecture, support, install, WebUI, profiles, CLI/exit codes, MacroDroid steps and exact commands, Tasker, ADB, scheduling ownership, boot, recovery, diagnostics, Android/OxygenOS conflicts, upgrade migration, uninstall, limitations, and OnePlus 12 recommendation without medical claims.

- [x] **Step 2: Run full verification**

Run:

```powershell
rtk proxy sh tests/run-tests.sh
rtk proxy sh -n action.sh customize.sh service.sh system/bin/bluefilter system/bin/bluefilter-core system/bin/bluefilter-daemon tests/*.sh
rtk proxy rg -n "\r$" -g "*.sh" -g "bluefilter*" .
rtk git diff --check
rtk git status --short
```

Expected: all tests pass, shell syntax passes, no CRLF matches, no diff errors, and only intended files changed.

- [x] **Step 3: Review requirements and diff**

Check every user deliverable against implementation; inspect security boundaries, reset behavior, scheduler exclusions, WebUI console, responsive screenshots, config migration, and upstream fork-specific features before completion.
