---
name: battery-refresh-resume-heal-2026-10-24
description: battery-refresh hibernate-resume 120Hz bug root cause + self-heal
  rework EXECUTED, live-proven, staged; pending user switch
metadata:
  node_type: memory
  type: project
  originSessionId: sess_bc12e6f6-2d93-4701-8079-dc90fd597975
---

EXECUTED 2026-10-24, QC green, STAGED (no commit/switch — house rules). Supersedes the "triggers" model of [[yoga-energy-idle-2026-09-22]].

**Bug:** user booted on battery → 120Hz stuck. Not a boot: s2h hibernate resume (suspended Oct 21 21:47 → hibernated 23:47 → resumed Oct 24 00:13; `who -b` still said Oct 18). On thaw Hyprland re-applies the configured `3072x1920@120`; old daemon only acted on (power,lid) *changes* vs remembered `last="bat,open"` → never re-applied, journal literally empty. ryzen-tdp survived the same resume only because it has a watchdog timer.

**Fix (home/battery-refresh.nix only):** dropped `last` change-detection; loop now probes actual panel Hz every poll and applies on mismatch (`have != want`). Self-heals resume, reload, manual switches within one poll (5s), logs each corrective apply ("restoring N Hz (pwr)").

Key facts:
- Hyprland probe: `hyprctl -j monitors | jq -r '.[] | select(.name=="eDP-1") | .refreshRate | round'` — 0.55 JSON has TOP-LEVEL `refreshRate`, no `currentMode` object. jq added to runtimeInputs.
- GNOME probe: `gnome-monitor-config list` (NO `get` subcommand!), active mode line ends in ` CURRENT` (`%dx%d@%g [id: '...']...`), tool = jadahl/gnome-monitor-config, deprecated vs gdctl. gnused+jq added.
- Nix gotchas hit: shell `${var}` inside ''-string must be `''${var}` (undefined-variable eval error otherwise); `nix flake check` only EVALUATES nixosConfigurations — writeShellApplication/shellcheck gate needs a real build (`nix build .#...home-manager.users.dk.home-files` realizes the daemon).
- Verification recipe (reusable): set 120 on battery via `hyprctl eval`, wait 6s → old daemon silent (bug proven); run new script 8s → logs restore, panel @60.
- Immediate relief applied live 2026-10-24 via hyprctl eval (session-local).

Docs synced: hosts/yoga/home.nix comment, REPO_OVERVIEW §160 table + §530 panel-refresh paragraph. Live service still runs the PRE-refactor build ([[fleet-automation-review-exec-2026-10-19]] staging) — fix lands at next switch together with that batch. Post-switch: `journalctl --user -u battery-refresh` should show "restoring" lines after any hibernate resume.

**Poll-cost question (user asked "isn't 5s too aggressive?") — answered with measurements, no change made:** the 5s sleep loop is PRE-EXISTING (always polled power+lid); the fix only added a probe inside the existing tick. Measured live: probe tick (`hyprctl -j monitors | jq`) ≈ 20ms CPU per 5s (~0.5% of one core, ~0.005W) vs old sysfs tick ~4ms; negligible vs lucid+Hyprland idle (~180ms CPU/s) and 3 orders below the 0.5–1W the 60Hz switch saves. Probe is read-only (no mode set unless mismatch), skipped when lid closed, frozen during sleep. Why polling not events: compositor-side resets (thaw/reload) emit NO userspace event — Hyprland socket2 has no mode-changed event. Interval is a knob: `desktop.battery-refresh.pollInterval` (default 5) — recommendation given: keep 5.

