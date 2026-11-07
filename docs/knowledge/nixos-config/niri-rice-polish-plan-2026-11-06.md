---
name: niri-rice-polish-plan-2026-11-06
description: PLAN ready but ExitPlanMode DENIED (permission denied, NOTHING
  executed) — unixporn-style elegance pass on yoga-niri; user decisions locked
  via AskUserQuestion (active-only Rosé Pine ring, Rosé Pine terminal sync,
  kitty frost + motion polish + xwayland-satellite, Bibata cursor REJECTED);
  full current-state grounding + approved KDL/Nix values in file
metadata:
  node_type: memory
  type: project
  originSessionId: session_1a204d69b11e758ca3169109e653a7ee
---

# niri rice polish plan 2026-11-06 — APPROVED scope, ExitPlanMode DENIED, NOTHING executed

User asked "make niri more modern & elegant, like unixporn, minimal blurred". Exploration + AskUserQuestion done; **ExitPlanMode was denied (permission denied)** — hand this plan to an executor session unchanged. Related: [[noctalia-niri-swap-exec-2026-11-06]] (staged on niri-testing underneath), [[noctalia-lockscreen-sleek-plan-2026-11-06]] (separate, also denied).

## User decisions LOCKED
1. **Focus ring: active-only** — `width 2`, `active-color "#c4a7e7ff"` (Rosé Pine iris), `inactive-color "#00000000"`; `border { off }` stays.
2. **Terminal palette → Rosé Pine**, conditioned on `config.desktop.noctalia.enable` in home/terminal.nix (Hyprland/lucid hosts keep Nord byte-identical): kitty explicit palette (no kitty-themes lookup; bg #191724 fg #e0def4 cursor #56526e sel #403d52, color1 #eb6f92 2 #31748f 3 #f6c177 4 #9ccfd8 5 #c4a7e7 6 #ebbcba 8 #6e6a86, brights mirror mains — verify hexes vs rose-pine/kitty upstream); bat `if noctalia then "Rose Pine"` (check `bat --list-themes | grep -i rose` first); fzf Rosé Pine subset; btop vendored theme via `pkgs.writeText` (don't depend on nixpkgs shipping one).
3. **Extras approved**: kitty frost (window-rule `background-effect { blur on; xray off }` for `^kitty$` — PROBE-GATED), airier layout (`gaps 8→12`) + motion polish (workspace-switch/window-movement/horizontal-view-movement/shift springs damping-ratio 0.9 stiffness 400 epsilon 0.0001; window-resize 150ms ease-out-quad; overview-open 250ms/close 200ms ease-out-expo; `overview { zoom 0.9 }`), xwayland-satellite (package only; niri ≥25.08 auto-spawns from PATH). **Bibata cursor REJECTED** (keep Posy Black 32).

## Current-state grounding (2026-11-06, working tree)
- niri 26.04 from **nixpkgs nixos-26.05** (no flake input); KDL = raw heredoc in `home/niri.nix` with a `runCommand` + `niri validate` build gate → **the dry-build IS the probe** for window-rule background-effect, animation block names, opacity — all unverified in 26.04.
- Current KDL: gaps 8, radius 16 + clip-to-geometry, shadow softness 24/spread 5/#0007, Nord ring #7d7eaa/#4c566a, blur passes 2/offset 5/noise 0.04/**saturation 1.0 pinned** (niri default 1.5 boosts wallpaper), bar/dock get NO `blur true` (dock-blur-while-hidden bug 11-06), `^noctalia-backdrop` place-within-backdrop. Animations: only window-open 220ms expo / close 150ms quad tuned; **stale comment says Noctalia at 0.8x but shell is at 1.15** (fix in passing).
- Noctalia v5.4.1: Rosé Pine builtin, mode auto (Berlin 52.52/13.40), glass panel, capsule bar 3 pills (capsule_opacity 0.68 GUI-tuned), dock smart-autohide+magnification, animation.speed 1.15 GUI-tuned. `programs.noctalia.settings` → config.toml store symlink; **`~/.local/state/noctalia/settings.toml` WINS** — do NOT edit noctalia.nix for looks; harvest via `noctalia config export merged`. Templates on: btop/gtk3/gtk4; **"niri" and "kitty" template ids must STAY off** (rewrite Nix-owned files).
- Kitty: Nord static (deliberate), opacity 0.93 (conditioned `!lucid`), padding 12pt, `--single-instance` wrap → needs restart after theme change.
- GTK = adw-gtk3-dark + noctalia.css via templates; icons Fluent-dark; cursor Posy Black 32 (theme.nix:22-24 shared by ALL hosts); fonts Inter/CaskaydiaCove + Google Sans Flex (shell). **No xwayland-satellite anywhere.**

## Execution + QC
Files: home/niri.nix, home/terminal.nix, modules/features/desktop-niri.nix (xwayland pkg), REPO_OVERVIEW.md sync (its noctalia row already stale). No new repo files (btop theme via writeText). QC: `nix fmt <explicit files>` + `scripts/test-suite fast` (3 defaults, proves terminal.nix conditioning on Nord hosts) + `fast yoga-niri`; VM battery SKIP (HM-only). Validate-gate failure = drop the rejected piece, re-run.
