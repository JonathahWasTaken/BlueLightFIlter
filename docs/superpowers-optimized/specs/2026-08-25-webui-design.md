# WebUI Design

## Product direction

**Design System:** rooted-device utility — OLED minimal control panel  
**Colors:** near-black surface, muted red primary, amber profile accent, high-contrast neutral text, distinct success/warning/error tokens  
**Typography:** system sans with strong hierarchy and tabular numeric values  
**Effects:** 160–220 ms opacity/transform feedback, reduced-motion fallback, no continuous decorative animation  
**Avoid:** emoji controls, tiny copy, equal-weight card stacks, shell code construction, and high-frequency live SurfaceFlinger preview

Primary audience is a phone user opening a narrow embedded WebView. Primary goal is one-tap enable/disable and profile selection. Advanced custom matrix controls are progressively disclosed.

## Architecture

The WebUI is a single dependency-free HTML file. Every mutation calls a fixed `bluefilter` command; it never writes config, state, or raw SurfaceFlinger transactions. User-selected values are constrained through allowlists or numeric/time validation before interpolation. Status comes from `bluefilter status --json`, creating one synchronization contract for CLI and UI.

Main layout:

1. Sticky status header and large on/off control.
2. Profile rail/grid with clear selected state and short descriptions.
3. Brightness/dim slider with explicit output value and save/apply behavior.
4. Collapsible custom matrix editor using 16 bounded numeric fields and reset-to-safe action.
5. Automation section for autoboot, schedule, and notification.
6. Recovery/diagnostic actions separated visually from normal controls.

The initial view shows a loading skeleton. Shell failures show an inline retry message. Buttons expose pending state and prevent duplicate calls. Toasts use `aria-live`; toggles have visible labels and keyboard focus. Touch targets are at least 48 px, safe-area padding is respected, and layouts are verified at 375, 768, 1024, and 1440 px.

## Interaction choices

Profile selection applies immediately only when the filter is on; otherwise it saves the default. Brightness changes update labels locally and apply on pointer/key release, preventing the old 60-calls-per-second Binder queue. Custom matrix submission requires an explicit Apply action and server-side validation.

## Failure-mode check

- Critical: WebUI string interpolation permits shell injection. Resolved by fixed command templates plus allowlisted profiles, decimal validation, and CLI validation as a second boundary.
- Critical: optimistic UI claims success after a failed shell call. Resolved by CLI exit/output contract and rollback with inline error.
- Minor: embedded hosts differ in callback error detail. Degraded errors remain actionable and diagnostics are linked.

## Testing

Static tests inspect required ARIA/semantic attributes and prohibit direct `service call`, `touch`, `rm`, `sed`, and config writes in WebUI JavaScript. Browser verification covers loading, success, error, pending, profile selection, narrow/desktop layouts, and runtime logs using a mocked `ksu` bridge.
