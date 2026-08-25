# Packaging, Diagnostics, and Documentation Design

## Packaging

Use the current official Magisk `module_installer.sh` as recovery `update-binary`; KernelSU and Magisk managers share the standard module structure and `customize.sh` helpers. Do not set `SKIPUNZIP`, allowing module files—including WebUI and action script—to be installed. `customize.sh` handles only permissions, migration, and upgrade state. Shell files ship with LF endings.

Version becomes 2.0.0 because the CLI/config/state contracts expand while compatibility aliases remain. APatch is described as architecturally likely to work through Magisk-module compatibility but not claimed as tested support.

## Diagnostics

`diag` reports API/release, manufacturer/model/build, ROM properties, root solution markers, SurfaceFlinger discovery, transaction 1015 expectation, state/config validation, active/default profile, brightness, scheduler ownership, daemon PID validity, autoboot, file modes, and known AOSP conflict settings.

`diag --test` runs a brief transform only when BlueLightFIlter is already active, then restores the exact module-computed matrix under a trap. When inactive it skips the transform because SurfaceFlinger has no matrix getter and applying identity could erase an Android/vendor transform. Diagnostics never claim visual success from exit status alone.

## Documentation

README sections cover architecture, support matrix, installation, WebUI, profiles, full CLI reference, MacroDroid exact setup, Tasker, ADB/root examples, scheduler ownership, boot, diagnostics, recovery, conflicts, upgrades, uninstall behavior, and limitations. Health claims are limited to user preference and visual comfort; no sleep or medical outcome is promised.

Recommended OnePlus 12 AMOLED starting point is `red-dim` at brightness `0.55`, with Android/OxygenOS Eye Comfort, Bedtime grayscale, color correction, inversion, and Reduce Bright Colors disabled to prevent last-writer conflicts. Users may raise brightness if shadow detail is too low.

## Failure-mode check

- Critical: custom recovery ZIP omits WebUI or lacks installer helpers. Resolved by official installer and archive-content validation.
- Critical: diagnostics leave a test matrix active. Resolved by trap-based restoration and refusing unsafe inactive tests.
- Minor: APatch behavior is unverified. Documented as untested rather than advertised.

## Testing

Validate shell syntax, ShellCheck where available, CRLF absence, required archive paths, executable modes represented by installer logic, documentation command examples against CLI help, static WebUI security checks, and a clean diff review.
