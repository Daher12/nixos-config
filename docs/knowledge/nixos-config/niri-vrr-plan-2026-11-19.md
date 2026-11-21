---
name: niri-vrr-plan-2026-11-19
description: PLAN ready (ExitPlanMode DENIED, NOTHING executed) — add vrr on to
  eDP-1 in home/niri.nix layered ON TOP of battery-refresh 120/60 switching;
  niri 26.04 VRR facts verified from the binary
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c4d78b2f-beb0-49e3-babc-18f923e4b118
---

PLAN 2026-11-19, ExitPlanMode DENIED → nothing executed. User decision (AskUserQuestion): **keep the 120/60 Hz battery-refresh switching + add `vrr on`** (rejected: VRR-only/always-120 — gives back the measured ~0.5–1 W battery saving during active use).

**Planned change (one functional line):** add `vrr on` to the generated `output "eDP-1"` block in home/niri.nix (outputKdl, ~lines 37–44) with a comment; one-clause comment sync in hosts/yoga/home.nix (~316) + REPO_OVERVIEW battery-refresh row / §Power tuning. DP-2 stays unmanaged (head-only `desktop.monitors`, see [[niri-multi-monitor-plan-2026-11-18]]) — session-scoped toggle: `niri msg output DP-2 vrr on`.

**niri 26.04 VRR facts (extracted from the pinned store binary, nixpkgs f684076):**
- Config: `vrr off | on | on-demand` per output block (NO `auto` value in 26.04). Grammar covered by the `niri validate` build gate in home/niri.nix — but dry-build does NOT execute runCommand; exercise it via `nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home-files`.
- Runtime IPC: `niri msg output <name> vrr <mode>` hot-applies; `niri msg outputs` shows "Variable refresh rate: supported, enabled|disabled".
- Composes with [[battery-refresh-niri-backend-2026-11-07]]: daemon switches MODES (nominal Hz), VRR adapts WITHIN the mode; the daemon probe reads nominal `current_mode` rate so they cannot fight.
- Both yoga outputs report VRR-capable from the driver (eDP-1 panel + DP-2 4K144 M27-4K-144-C).
- Power honesty: Intel PSR already covers idle static content, so VRR's idle win over fixed-60 is small; VRR is mostly UX (judder-free video, adaptive motion below the mode cap).

**Verification in plan:** `nix fmt home/niri.nix` (files explicit), home-files build (runs validate), `scripts/test-suite fast yoga`; live after switch: `niri msg outputs` shows enabled, daemon journal still logs 60↔120, optional battery power_now A/B idle.
