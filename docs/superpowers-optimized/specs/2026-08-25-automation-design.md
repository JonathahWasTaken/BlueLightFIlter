# Automation and Lifecycle Design

## Scope

Make manual commands, scheduling, boot, persistent notification, and automation apps share one serialized state machine. Eliminate unconditional daemon startup.

## State model

`enabled` becomes a small validated record containing `profile`, `brightness`, and `source` (`manual`, `schedule`, or `boot`). Its presence remains backwards-compatible. `.auto_enabled` exists only while the current active state is scheduler-owned. `.manual_off` suppresses scheduler reactivation for the remainder of the current night window after a user turns off a scheduler-owned filter.

Manual `on`, `toggle`, `apply`, and profile changes clear scheduler ownership. Manual `off` of a scheduler-owned state records the temporary override. At the next daytime evaluation the override is cleared. The scheduler only turns off state it owns, so a manual daytime or nighttime activation is never disabled at sunrise.

## Conditional daemon

`daemon-reconcile` starts the daemon only when schedule or notification is enabled and stops it when both are disabled. Boot runs reconcile after SurfaceFlinger becomes available. Every CLI setter for those features runs reconcile immediately. The daemon exits itself if both features become disabled or config becomes unavailable.

Polling remains at 60 seconds because Android shell modules have no small, portable cross-ROM alarm API. This cost exists only when a requested feature needs it. Notification state may lag by at most one poll interval; filter commands themselves remain instant.

## Boot and readiness

`service.sh` waits for `sys.boot_completed=1`, then probes both `service check SurfaceFlinger` and the public CLI readiness path with a bounded timeout. It avoids a fixed post-boot five-second sleep. Autoboot applies the saved profile with source `boot`; scheduling evaluation follows and does not claim manual state.

## Scheduling contract

Times are strict `HH:MM`. Equal start/end means a disabled/empty window rather than all day. Windows crossing midnight and same-day windows are both supported. Evaluation uses local device time, so timezone changes take effect at the next poll. Schedule setters are atomic and immediately evaluated.

## Failure-mode check

- Critical: scheduler disables a manual activation at sunrise. Resolved by explicit ownership.
- Critical: manual off is reversed one minute later. Resolved by a night-window override cleared only after leaving the window.
- Critical: concurrent WebUI/CLI/daemon writes corrupt state. Resolved by one CLI and one lock; WebUI never writes config directly.
- Minor: notification may be stale for under 60 seconds. Accepted to avoid a permanent high-frequency worker.

## Testing

Pure tests cover crossing-midnight, same-day, equal-time, manual ownership, manual-off suppression, stale PID handling, and conditional daemon decisions. Process-spawn behavior uses mock daemon and notification commands.
