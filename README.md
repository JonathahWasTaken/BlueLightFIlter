# BlueLightFIlter

BlueLightFIlter is a root module for Android 8.0 and newer. It applies a 4×4 color transform through SurfaceFlinger, Android's display compositor. The transform covers the composed display without an overlay window or accessibility service.

The module supports Magisk and KernelSU. It keeps the applied filter at zero CPU cost. A small shell worker runs only when you enable scheduling or the persistent notification.

## Before you install

SurfaceFlinger transaction `1015` is an internal Android interface. AOSP has kept it from Android 8 through Android 16, but a device maker can block, change, or remove it. Run `bluefilter diag` after installation.

BlueLightFIlter and Android display features can overwrite each other. Disable Night Light or Eye Comfort, Bedtime grayscale, color correction, color inversion, Reduce Bright Colors or Extra Dim, and display white balance before using this module. See [Android color transforms](#android-color-transform-conflicts).

Keep this recovery command available:

```sh
su -c 'bluefilter reset'
```

`reset` builds the identity matrix inside the CLI. It does not read `config.conf`.

## How it works

Android's framework composes Night Display, white balance, grayscale, Reduce Bright Colors, and inversion matrices, then sends one column-major matrix to SurfaceFlinger through transaction `1015`. BlueLightFIlter uses the same transaction. SurfaceFlinger exposes no interface that returns the current client matrix, so a root shell module cannot read and combine Android's matrix without guessing.

BlueLightFIlter uses a deterministic last-writer model:

- A BlueLightFIlter command replaces Android's current framework matrix.
- Android can replace the BlueLightFIlter matrix after a display-setting or user-state change.
- `status` reports BlueLightFIlter's recorded intent. It cannot prove the visible compositor state.

AOSP documents the matrix as column-major in [SurfaceFlinger.cpp](https://android.googlesource.com/platform/frameworks/native/+/refs/heads/main/services/surfaceflinger/SurfaceFlinger.cpp). Android's [DisplayTransformManager](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/services/core/java/com/android/server/display/color/DisplayTransformManager.java) uses the same transaction and matrix ordering.

## Supported root environments

| Environment | Status | Notes |
|---|---|---|
| Magisk | Supported | Uses the current Magisk module installer. |
| KernelSU | Supported | Uses the shared Magisk-style module layout and WebUI structure. |
| APatch | Untested | APatch accepts many Magisk modules, but this repository has no APatch device test. |

Some MIUI, HyperOS, One UI, ColorOS, and OxygenOS releases restrict Binder calls or reapply vendor display transforms. Support depends on the ROM build, SELinux policy, and root implementation.

## Installation

1. Download or build the module ZIP.
2. Install it from Magisk or KernelSU Manager.
3. Reboot.
4. Run `su -c 'bluefilter diag'` in a terminal.
5. Open the module WebUI from KernelSU, MMRL, or KSUWebUIStandalone.

The installer preserves schema 1 RGB settings, profile choice, schedule, notification setting, autoboot state, and enabled intent during a manager-based upgrade. It converts an old `custom=R G B` value into a diagonal 4×4 matrix. If schema 2 validation fails, the installer saves the rejected file as `config.conf.invalid` and installs safe defaults.

## Profiles

| Profile | Transform | Default compositor brightness |
|---|---|---:|
| `warm` | Warm diagonal RGB attenuation | `1.00` |
| `amber` | Strong green and blue attenuation | `1.00` |
| `deep-red` | Red-dominant diagonal RGB attenuation | `1.00` |
| `red` | Luminance-preserving monochrome red | `1.00` |
| `red-dim` | Red monochrome with lower output | `0.55` |
| `red-extra-dim` | Red monochrome with the lowest built-in output | `0.30` |
| `custom` | User-supplied validated 4×4 matrix | `1.00` |

The red profiles use this transform:

```text
L  = 0.2126R + 0.7152G + 0.0722B
R' = L
G' = 0
B' = 0
```

This transform maps green and blue detail into red luminance instead of discarding those channels into black.

`bluefilter brightness VALUE` scales the 3×3 color coefficients. It does not change Android's backlight or OLED brightness setting. The accepted range is `0.10` through `1.00`.

### OnePlus 12 AMOLED recommendation

Start with:

```sh
bluefilter on red-dim
```

`red-dim` uses compositor brightness `0.55`. It keeps image luminance detail while green and blue OLED subpixels receive no output from the matrix. Use `bluefilter brightness 0.65` if shadow detail feels too dark. Disable OxygenOS Eye Comfort, Bedtime mode grayscale, Nature Tone Display, Reduce Bright Colors, and accessibility color transforms first.

This recommendation concerns display appearance and emitted color. The project makes no medical or sleep-outcome claim.

## WebUI

The WebUI uses the same CLI as shell automation. It never writes configuration files or calls SurfaceFlinger itself.

The main screen provides:

- on/off control and active state;
- profile selection and compositor brightness;
- a validated custom 4×4 matrix editor;
- autoboot, schedule, and persistent notification settings;
- diagnostics and emergency reset.

Profile or state changes made from MacroDroid, Tasker, ADB, or a root terminal appear when you reopen or refocus the WebUI.

## CLI reference

`/system/bin/bluefilter` is the public automation API. Commands do not open a UI. Mutations print one short line. Errors go to stderr.

### Filter and status

```sh
bluefilter on                    # enable the saved profile
bluefilter on red-dim            # save and enable red-dim
bluefilter off                   # restore identity
bluefilter toggle                # toggle the saved profile
bluefilter toggle red-dim        # use red-dim when toggling on
bluefilter apply red             # save and enable red
bluefilter reset                 # emergency identity reset

bluefilter is-on                 # no output; exit 0 on, exit 1 off
bluefilter current               # active profile name or "off"
bluefilter status                # compact human output
bluefilter status --quiet        # no output; exit 0 on, exit 1 off
bluefilter status --json         # machine-readable state
```

Example JSON:

```json
{"enabled":true,"profile":"red-dim","brightness":0.55,"source":"manual","scheduled":false,"daemon":false,"autoboot":false,"compositorVerified":false}
```

`compositorVerified` stays `false` because SurfaceFlinger has no matrix readback API.

### Profiles and custom matrix

```sh
bluefilter profile list
bluefilter profile get
bluefilter profile set red-dim
bluefilter brightness
bluefilter brightness 0.50
bluefilter matrix get
bluefilter matrix set 1 0 0 0 0 0.5 0 0 0 0 0.2 0 0 0 0 1
```

Custom matrix validation enforces 16 decimal values, non-negative bounded coefficients, zero translation, homogeneous row `0 0 0 1`, bounded channel sums, and a minimum visible output. The CLI rejects a black or near-black matrix before it reaches SurfaceFlinger.

### Boot, schedule, and notification

```sh
bluefilter autoboot on
bluefilter autoboot off
bluefilter autoboot status

bluefilter schedule on
bluefilter schedule off
bluefilter schedule set 21:00 06:00
bluefilter schedule status

bluefilter notification on
bluefilter notification off
bluefilter notification status

bluefilter daemon-status
bluefilter daemon-reconcile
```

You do not need to start the daemon. Schedule and notification setters call `daemon-reconcile`. The worker stops after both features are disabled.

### Compatibility aliases

Existing commands remain valid:

```sh
bluefilter start
bluefilter start red-dim
bluefilter stop
bluefilter status
bluefilter reset
bluefilter diag
```

### Exit codes

| Code | Meaning |
|---:|---|
| `0` | Command succeeded, or predicate is true. |
| `1` | `is-on` or `status --quiet` found the filter disabled. |
| `2` | Invalid command, profile, matrix, time, brightness, or configuration input. |
| `3` | Root, SurfaceFlinger, daemon, or filesystem operation failed. |
| `4` | Another state-changing command held the lock too long. |

## MacroDroid

MacroDroid's [Power Button Toggle](https://www.macrodroidforum.com/wiki/index.php/Trigger:_Power_Button_Toggle) trigger counts screen on/off transitions. Its [Shell Script](https://www.macrodroidforum.com/wiki/index.php/Action:_Shell_Script) action can run the command through `su`.

### Triple power-button toggle

1. Open MacroDroid and tap **Add Macro**.
2. Add the **Power Button Toggle** trigger. Select **3 toggles**.
3. Add the **Shell Script** action.
4. Select **Rooted** execution and enable **Block next actions until complete**.
5. Enter:

   ```sh
   bluefilter toggle red-dim
   ```

6. Save the macro and grant MacroDroid root access when your root manager asks.
7. Test with three power-button toggles inside MacroDroid's configured time limit. The default limit is 3500 ms.

The trigger observes screen transitions rather than the physical key. OxygenOS can miss presses if the screen has not completed its on/off transition. Increase **MacroDroid Settings > Maximum time to complete toggles** if needed.

Useful MacroDroid commands:

```sh
bluefilter toggle red
bluefilter toggle red-dim
bluefilter on red-extra-dim
bluefilter off
bluefilter reset
```

Do not wrap the command in `su -c` when the Shell Script action already uses **Rooted** mode. If you use a non-root shell action, enter:

```sh
su -c 'bluefilter toggle red-dim'
```

## Tasker

1. Create a Task and add **Run Shell**.
2. Enter `bluefilter toggle red-dim`.
3. Enable **Use Root**.
4. Attach the Task to a time, hardware-button, gesture, or event Profile.

Use `bluefilter is-on` when a Task needs a predicate. Exit `0` means enabled and exit `1` means disabled.

## ADB and root-shell examples

From a computer:

```sh
adb shell su -c 'bluefilter status --json'
adb shell su -c 'bluefilter on red-dim'
adb shell su -c 'bluefilter brightness 0.60'
adb shell su -c 'bluefilter off'
adb shell su -c 'bluefilter reset'
```

From an Android root terminal:

```sh
su
bluefilter toggle red-dim
```

## Scheduling behavior

The scheduler supports windows that cross midnight, such as `21:00` to `06:00`, and same-day windows, such as `06:00` to `21:00`. Start and end cannot match.

The state file records who enabled the filter:

- The scheduler turns off only a state that the scheduler enabled.
- A manual activation survives sunrise.
- A manual off during an active night window stays off until the window ends.
- The next daytime evaluation clears that manual-off override.
- Timezone changes take effect on the next 60-second evaluation.

Boot clears stale runtime and PID files. Autoboot restores the saved profile after SurfaceFlinger becomes available. The scheduler then evaluates the current local time.

## Diagnostics

```sh
bluefilter diag
bluefilter diag --test
```

`diag` reports Android and device builds, root environment, SurfaceFlinger availability, transaction expectation, config validity, profile and state, schedule, daemon, autoboot, relevant file modes, SELinux mode, and known Android conflict settings.

`diag --test` sends a brief red test only while BlueLightFIlter is active. It restores the exact module-computed active matrix after the test. It skips the transform while inactive because the module cannot read and restore an unknown Android or vendor matrix.

The Android `service` utility does not propagate the Binder transaction status to its process exit code. Diagnostics can prove that SurfaceFlinger exists and that the local command ran. You must confirm the visual result on the device.

## Android color-transform conflicts

Avoid combining BlueLightFIlter with:

- Android Night Light or OxygenOS Eye Comfort;
- accessibility grayscale, color correction, or inversion;
- Reduce Bright Colors, Extra Dim, or Bedtime mode;
- display white balance or Nature Tone Display;
- ROM-specific display color modes that reapply after unlock, rotation, HDR changes, or user switches.

SurfaceFlinger composes global saturation and daltonizer paths after the client matrix on current AOSP. Vendor code can differ. BlueLightFIlter does not guess or stack private vendor matrices.

## Configuration and state files

The module stores data under `/data/adb/modules/bluelightfilter`:

| Path | Purpose |
|---|---|
| `config.conf` | Schema 2 profile, brightness, custom matrix, schedule, and notification settings. |
| `enabled` | Recorded active profile, brightness, and owner. |
| `autoboot` | User request to restore the filter after boot. |
| `.auto_enabled` | Current state belongs to the scheduler. |
| `.manual_off` | User suppressed the current night window. |
| `daemon.pid` | Conditional worker PID. |

The parser reads named sections and keys. It never sources `config.conf` as shell code. State-changing commands use one lock and same-directory atomic file replacement.

## Recovery

Run this first if a custom setting produces an unusable display:

```sh
su -c 'bluefilter reset'
```

From ADB:

```sh
adb shell su -c 'bluefilter reset'
```

If the ROM blocks the command, reboot to disable or remove the module from your root manager. A reboot restarts SurfaceFlinger with its normal identity/framework state.

## Uninstall

1. Run `su -c 'bluefilter reset'`.
2. Remove the module from Magisk or KernelSU Manager.
3. Reboot.

Removing module files does not send an identity matrix. Reset before removal, or reboot to restart SurfaceFlinger.

## Development and tests

The host-side suite mocks Android commands and tests config parsing, migration, matrix construction, bounds, CLI exits, toggle idempotence, malformed config recovery, scheduler ownership, conditional daemon behavior, diagnostics restoration, packaging, and WebUI security contracts.

```sh
sh tests/run-tests.sh
sh -n action.sh customize.sh service.sh system/bin/bluefilter system/bin/bluefilter-core system/bin/bluefilter-daemon
```

Device tests remain necessary for Binder permission, SELinux, notification syntax, WebUI host integration, and visual confirmation on each ROM.

## License

BlueLightFIlter is licensed under GPL-3.0. See [LICENSE](LICENSE).
