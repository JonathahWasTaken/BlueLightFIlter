# Project Map
_Generated: 2026-08-25 | Git: 21fb482_

## Directory Structure
`system/bin/` — Android shell CLI and optional scheduling/notification daemon.
`webroot/` — KernelSU/MMRL-compatible single-page WebUI.
`META-INF/com/google/android/` — Recovery/Magisk ZIP entrypoints.
`tests/` — Dependency-free host tests, fixtures, mocks, and WebUI preview harness.
`docs/superpowers-optimized/` — Approved architecture specifications and implementation plan.

## Key Files
`system/bin/bluefilter` — Public root-shell CLI; applies and resets SurfaceFlinger transaction 1015 matrices and manages state.
`system/bin/bluefilter-core` — Shared POSIX-shell validation, matrix, config, state, and schedule primitives.
`system/bin/bluefilter-daemon` — Polling scheduler and persistent-notification worker.
`webroot/index.html` — Self-contained WebUI using the WebUI shell bridge.
`service.sh` — Post-boot entrypoint; applies autoboot state and launches the daemon.
`customize.sh` — Magisk/KernelSU installation, permissions, config preservation, and migration.
`config.conf` — Shipped configuration defaults and on-device schema.
`action.sh` — Module action launcher for KSUWebUIStandalone or MMRL.
`module.prop` — Root-module identity, version, minimum API, and WebUI metadata.
`META-INF/com/google/android/update-binary` — Flashable ZIP extraction and customization entrypoint.
`.gitattributes` — Enforces LF storage for Android/Magisk runtime files and metadata.
`README.md` — User documentation and current compatibility claims.

## Critical Constraints
- Runtime scripts target Android `/system/bin/sh`; avoid Bash-only syntax and desktop-only utilities.
- Shipped scripts, config, and module metadata must be LF-only; Magisk BusyBox `ash` treats CRLF control words as syntax errors.
- `/system/bin/bluefilter` is a public automation API and must keep `start`, `stop`, `status`, `reset`, and `diag` compatibility.
- SurfaceFlinger matrix operations must always retain a config-independent identity-matrix recovery path.
- SurfaceFlinger transaction 1015 is a last-writer interface; Android and vendor color-transform composition cannot be recovered safely from a root shell.
- The `service` CLI does not expose Binder transaction status, so persisted state records intent rather than verified pixels.
- Existing on-device configuration and enabled/autoboot state must survive module upgrades.
- Filter should consume no ongoing CPU after application; daemon may run only when scheduling or notification requires it.
- Magisk and KernelSU compatibility are required; APatch support may be documented only when technically justified.

## Hot Files
`system/bin/bluefilter`, `system/bin/bluefilter-core`, `system/bin/bluefilter-daemon`, `webroot/index.html`, `service.sh`, `customize.sh`, `config.conf`, `README.md`
