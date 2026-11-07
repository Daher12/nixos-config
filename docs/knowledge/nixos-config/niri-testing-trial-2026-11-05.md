---
name: niri-testing-trial-2026-11-05
description: EXECUTED+QC green STAGED on branch niri-testing — yoga-niri attr
  (niri 26.04 + stock DMS), no uwsm, greeter=niri; pending user switch+smoke;
  flake-module import duplication gotcha
metadata:
  node_type: memory
  type: project
  originSessionId: session_fc536200640e392a3c8cdb16e7aee9a9
---

niri trial, staged in main's shared index 2026-11-05 (branch `niri-testing` is an EMPTY pointer at main tip 3388242 — nothing committed to it; see [[branch-split-plan-2026-11-05]] for the approved split layout where niri-testing = dux-shell + 1 niri commit).

**Executed (all STAGED, QC green — `test-suite fast` OK on yoga yoga-niri latitude nix-media vps):**
- Third host attr `yoga-niri` = `profiles = [ laptop desktop-niri ]` (yoga/yoga-gnome untouched; fast proves byte-level eval parity for their dry-builds).
- `modules/features/desktop-niri.nix`: `programs.niri.enable` (nixpkgs 26.05 module = niri 26.04, session entry `niri`, xdg-desktop-portal-gnome) + `programs.dank-material-shell {enable,systemd.enable}` (REUSES the existing `dux-shell` flake input — no new input) + greeter `programs.dms-greeter.compositor.name = "niri"` (upstream enum native) + `defaultSession = "niri"`.
- `home/niri.nix`: hand-written KDL through `niri validate -c` runCommand gate (broken KDL fails rebuild). Binds = Hyprland muscle-memory map via `dms ipc call …` (verb form verified by dux-shell eval branch, home/hyprland.nix shellIpc). Carries `include optional=true "dms/*.kdl"` fragments (binds-next first, binds last) so DMS Settings owns colors/layout/binds live.
- No uwsm: niri 26.04 session = niri-session → niri.service `BindsTo=graphical-session.target` → dms.service (WantedBy) auto-starts. Hyprland needs uwsm ONLY because it lacks this.
- `desktop.dms.enable` pushed true on niri attr → reuses home/dms.nix seed + grayscale theme + theme.nix gtk ownership unchanged.
- battery-refresh `mkForce false` on niri attr (Hyprland/GNOME daemons only; niri backend unharvested). Persistence: `.config/niri` added (DMS writes dms/*.kdl fragments there).
- 3-way mutual-exclusion assertions (desktop-niri vs hyprland vs gnome).

**Why:** user pivoted from mango (abandoned) → niri + stock DMS after effort comparison (DMS = zero packaging, upstream nixosTests; desktop-shell = qml-niri plugin + no lock screen + niri≥26.04 pin). DMS upstream HM module is BANNED in this repo (assigns programs.quickshell, defined nowhere) — settings seed lives in home/dms.nix.

**Gotcha (durable):** importing the same flake-module attrset (`inputs.X.nixosModules.Y`) from two repo modules does NOT dedupe — each evaluation yields a fresh module identity → "option already declared" breaks EVERY host eval. Import once unconditionally (desktop-hyprland.nix pattern), never "for self-containment".

**QC round 2 (same day, self-review):** found+fixed 2 real KDL defects against the `dms doctor` contract (core/cmd/dms/commands_doctor.go — it statically checks config.kdl): (1) `include "dms/binds-next.kdl"` must sit ABOVE the user's binds (later-wins merge; mine was at the bottom → DMS version-dependent defaults would override the muscle-memory binds) — moved to top of config.kdl; (2) `Mod+Shift+Slash` double-fires as Mod+Shift+7 on de/es/se layouts (doctor warns exactly this) — bind removed, DMS binds Mod+Shift+question for its shortcuts panel. Verified non-issues: niri create_dir_all's the screenshot parent (~/Bilder/Screenshots needs no mkdir); cursors work on niri (systemd.user.sessionVariables/environment.d load into the user manager, and niri.service is started BY the user manager → inherits XCURSOR_*); programs.dconf rides programs.niri's wayland-session.nix. Re-gated: niri validate + fast OK.

**Pending:** user rebuild `nus yoga-niri switch` (or test-suite flow) → greeter (on niri!) → smoke: DMS bar/lock/notifications, binds, overview (Mod+Tab), screencast portal, Xwayland app, keyring at greeter login, DMS settings persistence across reboot. VM battery: SKIP recommended (no VM test boots a graphical session — nothing there exercises niri/DMS).

Related: [[vps-watchdog-exitnode-plan-2026-11-01]] (parallel staged work on same branch), [[test-suite-shared-runner-2026-11-01]], [[spotify-cache-persistence-2026-11-01]]
