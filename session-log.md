# Session Log

## 2026-08-25 — Production redesign [saved]

**Goal:** Audit and productionize BlueLightFIlter for rooted Android, MacroDroid, boot automation, diagnostics, and KernelSU-compatible WebUI use.

**Decisions:**
- Keep SurfaceFlinger transaction 1015 as the backend and serialize all matrices in Binder column-major order.
- Make `bluefilter` the only mutation boundary for the WebUI, boot script, daemon, and automation tools.
- Preserve explicit intent state and schedule ownership; run the daemon only for enabled scheduling or notification.
- Validate complete custom matrices and their brightness-scaled result before changing config or compositor state.
- Preserve and migrate schema-v1 installs without sourcing untrusted configuration.
- Document transaction 1015 as last-writer behavior because a root shell cannot retrieve and safely compose Android or vendor transforms.

**Rejected:**
- A privileged Android companion app: larger trust and maintenance surface without solving vendor compositor variance.
- Guessing or reconstructing the current vendor color matrix.
- Claiming APatch support or confirmed visual application without device evidence.

**Open device checks:** Verify transaction access, SELinux behavior, boot timing, OxygenOS display-feature conflicts, and perceived profile strength on the target OnePlus 12.
