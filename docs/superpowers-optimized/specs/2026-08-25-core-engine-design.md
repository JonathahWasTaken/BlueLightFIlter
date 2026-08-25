# Core Engine Design

## Scope

Replace diagonal-only handling with a testable full-matrix engine, a stable automation-grade CLI, safe configuration parsing, and synchronized state changes. Keep `/system/bin/bluefilter` as the public entrypoint and retain `start`, `stop`, `status`, `reset`, and `diag` aliases.

Non-goals: a normal Android app, per-application transforms, guessing vendor-private Binder APIs, or claiming the compositor state can be read back when AOSP exposes no getter for transaction 1015.

## Evidence and approach

AOSP Android 8 through Android 16 and current `main` all implement transaction 1015. Current SurfaceFlinger explicitly reads a column-major `mat4`. Android's `DisplayTransformManager` composes framework matrices by level and writes their product through the same transaction; a direct module call therefore replaces that framework product. SurfaceFlinger subsequently multiplies global saturation and daltonizer transforms, but not the framework matrix that BlueLightFIlter displaced.

Three approaches were considered:

1. Keep RGB-only shell code. Smallest, but cannot implement luminance-preserving red and keeps duplicated unsafe parsing.
2. Add a shared POSIX-shell core and keep direct transaction 1015. Chosen: small, testable, compatible, and honest about overwrite conflicts.
3. Add a privileged Android service to join `DisplayTransformManager`. Rejected: large signing/SELinux/ROM burden with no stable third-party API.

## Architecture

`bluefilter-core` owns config reads/writes, built-in profiles, custom-matrix validation, dim multiplication, schedule predicates, locking, state serialization, and JSON escaping for validated fields. `bluefilter` owns argument parsing, SurfaceFlinger calls, diagnostics, and lifecycle commands. The daemon sources only the shared pure helpers and calls the CLI for mutations.

All state-changing public commands take a single atomic directory lock. State files are written to a same-directory temporary file and renamed. Stale locks and PID files are validated against live processes. A successful local `service` process is the strongest available signal; diagnostics state clearly that AOSP's `service` utility ignores Binder transaction status and SurfaceFlinger provides no readback API.

## Matrix contract

Matrices are 16 finite decimal values serialized column-major. Built-ins:

- `warm`: diagonal warm attenuation.
- `amber`: stronger blue/green attenuation.
- `deep-red`: diagonal red-dominant mode.
- `red`: luminance-preserving monochrome red.
- `red-dim`: red luminance matrix at a lower base output.
- `red-extra-dim`: red luminance matrix at the lowest built-in output.
- `custom`: validated config matrix.

For the conceptual row matrix `R' = 0.2126R + 0.7152G + 0.0722B`, serialized data is `0.2126 0 0 0 0.7152 0 0 0 0.0722 0 0 0 0 0 0 1`. A configurable brightness multiplier in `[0.10, 1.00]` scales only the 3×3 color coefficients. Custom matrices allow only non-negative coefficients, zero translation, identity homogeneous row, bounded output-row sums, and at least one visible output channel.

`reset` constructs identity internally before reading config and removes module state even if config is malformed. It never depends on the selected profile.

## CLI contract

Mutations print one stable line; errors go to stderr. Exit codes: `0` success/on, `1` disabled predicate, `2` usage or invalid input, `3` SurfaceFlinger failure/unavailability, `4` lock contention.

- `on [profile]`, `off`, `toggle [profile]`, `reset`
- `start [profile]` and `stop` compatibility aliases
- `is-on` (silent predicate), `current`
- `status`, `status --quiet`, `status --json`
- `profile`, `profile list|get|set <name>`
- `apply <profile>` as an explicit profile-and-enable operation
- `brightness [value]`
- `autoboot on|off|status`
- `schedule on|off|set HH:MM HH:MM|status|evaluate`
- `notification on|off|status`
- `daemon-start|daemon-stop|daemon-status|daemon-reconcile`
- `diag [--test]`

## Migration and recovery

Schema version 2 adds `[meta] schema=2`, a full custom matrix, brightness, and default profile. Existing `custom=R G B` is migrated to a diagonal 4×4 matrix. Existing schedule, notification, enabled, and autoboot state are preserved. Invalid files fall back to safe defaults for normal commands; setters repair only known keys. `reset` remains independent.

## Failure-mode check

- Critical: row/column confusion can produce black output. Resolved by exact column-major vectors and tests asserting luminance maps green and blue into red.
- Critical: a stale lock can disable recovery. Resolved by stale-owner cleanup and a reset path that does not parse config.
- Critical: Android or OxygenOS can overwrite the transform later. Not solvable without a privileged framework integration; status and docs describe module intent, not verified compositor state, and diagnostics report conflicts.
- Minor: vendor ROMs may renumber/block private transactions. Diagnostics report failure; no speculative vendor codes are attempted.

## Testing

A dependency-free shell harness tests parsing, profiles, matrix construction, bounds, JSON, CLI exits, aliases, toggle idempotence, lock cleanup, malformed config, and mocked SurfaceFlinger failures. Device-only diagnostics and interactive transforms remain explicitly separated.
