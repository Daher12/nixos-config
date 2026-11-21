---
name: niri-vrr-edp1-2026-11-19
description: VRR always-on added to eDP-1 niri output block EXECUTED, validate
  gate + fast green, staged uncommitted; niri 26.04 VRR grammar facts in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c4d78b2f-beb0-49e3-babc-18f923e4b118
---

EXECUTED 2026-11-19: `variable-refresh-rate on-demand=false` added to the generated `output "eDP-1"` block in `home/niri.nix` (always-on VRR riding on top of the battery-refresh 120/60 mode switching — user chose keep-daemon-plus-VRR; measured ~0.5–1 W active-use saving preserved). Comment-only sync in `hosts/yoga/home.nix` + REPO_OVERVIEW.md (niri.nix row, §Power tuning). Validate gate green, `test-suite fast yoga` OK, STAGED-UNCOMMITTED (no commit per house rule).

**niri 26.04 VRR grammar (all validate-gate/binary-proven — a planned `vrr on` was rejected live):**
- Output node: `variable-refresh-rate on-demand=<bool>` (knuffel property) → `Vrr { on_demand }` in niri-config/src/output.rs v26.04. Semantics from `is_vrr_always_on`/`is_vrr_on_demand`/`is_vrr_always_off`: absent = off, `on-demand=false` = ALWAYS on, `on-demand=true` = only when a window matching a VRR window-rule is on the output. Bare node `vrr on` / `vrr "on"` → "unexpected node"; `variable-refresh-rate true` (bare arg) → "unexpected argument".
- Window-rule: OPPOSITE shape — `variable-refresh-rate <bool>` as an ARGUMENT (marks the window as VRR-demanding; child-block form errors "additional argument required").
- IPC: `niri msg output <o> vrr <ON|OFF>` (+ optional `--on-demand`) — OutputAction::Vrr; help says temporary overrides are forgotten when the config FILE changes → the file carrying always-on VRR is the durable layer, config reloads re-apply it.
- `niri validate` catches both grammar AND schema (ran in the home-files build's runCommand gate — dry-build alone does NOT execute it; same lesson as [[battery-refresh-niri-backend-2026-11-07]]).
- KDL trap while bisecting one-liner test files: the LAST node before a closing `}` still needs a terminator (`;` or newline) — `x true }` on one line is a parse error, not schema rejection.

**Composition fact:** battery-refresh probes the nominal `current_mode` rate from `niri msg -j outputs`, which VRR never changes → daemon mode switches and VRR compose without fighting.

**Live-verify pending (user, after `nus` switch):** `niri msg outputs` should show eDP-1 "supported, enabled"; hot-apply available pre-rebuild via `niri msg output eDP-1 vrr on`; DP-2 (4K144) stays unmanaged (desktop.monitors head-only) — session toggle `niri msg output DP-2 vrr on`. Optional battery A/B: `/sys/class/power_supply/BAT*/power_now` static-screen, vrr off vs on (Intel PSR already covers much of idle → no promised delta).
