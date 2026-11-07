---
name: compositor-evaluation-mango-2026-11-04
description: WM evaluation (mango chosen, wiring plan built, ExitPlanMode DENIED
  nothing executed) — full candidate matrix + repo wiring facts + mango plan
metadata:
  node_type: memory
  type: project
  originSessionId: session_fc536200640e392a3c8cdb16e7aee9a9
---

ABANDONED BY USER 2026-11-05 ("rollback, skip mangowm") before any execution — pivoted to niri+DMS, see [[niri-dms-yoga-plan-2026-11-05]]. Historical: PLAN ONLY (ExitPlanMode DENIED 2026-11-04, NOTHING executed). User asked to evaluate another WM; criteria = fluidity/animations first, efficiency, easy zcode setup, tiling, quickshell/lucid compat.

**Decision: mango** (github:mangowm/mango) as a sidecar trial session on the `yoga` attr. Shell preference: "probably dms, if possible a smooth quickshell bar like lucid-shell" (phase 2).

**Candidate facts (researched 2026-11-04):**
- **mango**: C/wlroots, dwl-based + scenefx (blur/shadows/corners/opacity), smooth open/move/close + tag-transition animations, dwm tags model, hot-reload, ~4k stars. NOT in nixpkgs but own flake with `nixosModules.mango` (`programs.mango`: enable/addLoginEntry/package; sessionPackages registration, wlr+gtk portals w/ config.mango section, all mkDefault — benign merge) AND `hmModules.mango` (`wayland.windowManager.mango`: settings attrset flattened to key=value `~/.config/mango/config.conf`, autostart_sh, **build-time config validation** `mango -c $out -p`, mango-session.target).
- **river (riverwm/river, nixpkgs 0.4.2)**: REDESIGNED non-monolithic — no window management at all, external WM via river-window-management-v1 (tinyrwm), no animations. river-classic 0.3.15 in nixpkgs = the dwm-style tiler, but zero animations/eyecandy.
- **Aqueous**: Zig river-fork, render-time animations + Vulkan effects, declarative `shell = "pearl"|"dms"|"noctalia"|"none"` (DMS first-class — matches user pref) — but Nix packaging UNBUILDABLE: pins `zig_0_17` (nixpkgs unstable tops out at 0.15.2), README admits never Nix-built; module only 6 options and machine-owning (hard portal pinning); 56 stars. Consumable later via flake=false input + their nix/overlay.nix (builds from repo tree, cleanSourceWith ../.).
- **niri** (nixpkgs 25.11): noted as the fluidity benchmark, unlisted by user; not chosen.
- **lucid-shell is Hyprland-bound everywhere** (support/hypr deployment, keybinds.json executed by Hyprland, hyprctl) — cannot run on ANY non-Hyprland compositor; quickshell core runs on any layer-shell compositor.

**Repo wiring facts confirmed:** `inputs` reaches NixOS modules via specialArgs (precedent desktop-hyprland.nix:36 dank-greeter import) and HM via extraSpecialArgs; aggregators are explicit lists (`modules/features/default.nix`, `home/default.nix`); sidecar pattern = `features.trial-mango.*` (avoids desktop-* mutual-exclusion assertions); enable goes in hosts/yoga/default.nix; greeter lists sessions from sessionPackages; known trap = lucid units WantedBy graphical-session.target would crash-loop under mango → gate with ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland.

Full 6-touchpoint plan (flake input mango + trial-mango.nix + home/mango.nix + 2 aggregator edits + hosts/yoga enable, waybar phase-1 bar, persistence .config/mango) was in the denied ExitPlanMode payload. Related: [[desktop-switch-architecture-2026-10-13]], [[plans-for-weaker-executor]].
