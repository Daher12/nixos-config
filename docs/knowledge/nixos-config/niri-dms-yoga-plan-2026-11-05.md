---
name: niri-dms-yoga-plan-2026-11-05
description: niri+DMS yoga-niri attr plan (plan-mode session, ExitPlanMode DENIED 2x, NOTHING
  executed) — user pivoted off mango; decisions locked (yoga-niri attr + DMS shell); niri/DMS/
  desktop-shell research facts + full self-contained wiring plan inside
metadata:
  node_type: memory
  type: project
  originSessionId: session_fc536200640e392a3c8cdb16e7aee9a9
---

PLAN ONLY (ExitPlanMode denied 2026-11-04 AND 2026-11-05, NOTHING executed in this session). Continuation of [[compositor-evaluation-mango-2026-11-04]]: user said "rollback, skip mangowm, go for niri plan deep integration with custom shell, either DMS or hashankur/desktop-shell".

## User decisions (locked via AskUserQuestion)

1. **niri on a third host attr `yoga-niri`** (profiles swap `[ "laptop" "desktop-niri" ]`, mirroring yoga-gnome) — NOT a sidecar session (two quickshell shells sharing the user systemd instance = the lucid-units trap, bidirectional).
2. **Shell = DMS (dux-shell)** after an explicit effort comparison (user asked "is desktop-shell the same effort?"). DMS = less effort on BOTH axes (integrate + keep updated); desktop-shell = lucid-style patch tax + bus-factor-1 qml-niri plugin, deferred but trialable later via `qs -c neue` with zero integration (git clone to ~/.config/quickshell/neue).

## Research facts (2026-11-05)

- **niri**: nixpkgs 25.11 + built-in `programs.niri` NixOS module (enable/package/useNautilus; session + portals). Latest release **v26.04** (Apr 2026) — nixpkgs is ONE release behind. Screencast via xdg-desktop-portal-gnome; Xwayland via xwayland-satellite (≥25.08); animations+custom shaders, gradient borders, blur, overview. Fallback if nixpkgs niri too old for DMS: `github:niri-wm/niri` official overlay (`overlays.default`, v26.04+).
- **DMS = dux-shell** (sibling of the already-used dux-greeter; niri is its FIRST-class platform — originally built for niri, niri author added ext-workspace protocol for it). Full shell (lock/idle/notifications/launcher/clipboard/polkit agent). Flake exports `homeModules.dank-material-shell` + **`homeModules.niri`** (niri-specific presets) + `nixosModules.dank-material-shell` + upstream nixosTests; `packages.quickshell` just re-exports `pkgs.quickshell` (their patched one would be used); `mkModuleWithDmsPkgs` injects dmsPkgs from downstream pkgs. Config in `~/.config/dms` (plugins.lock.json); `dms ipc` CLI.
- **desktop-shell (hashankur)**: quickshell/QML, niri-only via **qml-niri** plugin (C++/Qt6/CMake, has own flake, 113★, "compatible with niri v26.04+" ⚠️ = version wrinkle vs nixpkgs 25.11 → would force the niri overlay). Deps otherwise already in repo (quickshell ≥0.3.0 ✓, cliphist ✓, wl-clipboard ✓, MoreWaita icons). No lock screen (roadmap), no packaging, 40★.
- **HM niri config modules**: typed `programs.niri.settings` comes from sodiboo/niri-flake; upstream HM module still open (issue #7250). Plan chose hand-written KDL + build-time `niri validate` gate instead (zero new inputs).
- nixpkgs' old `services.displayManager.dms-greeter` module enum allows `compositor.name = "niri"` (repo uses the flake `programs.dms-greeter` instead).

## The denied plan (self-contained summary)

Step 0: clone dux-shell, read `distro/nix/{home,niri,nixos}.nix` for REAL option names before writing anything. Then: flake input `dms` (follows nixpkgs, drop follows if build fails) + manual-pin/bump exclusion + attr `yoga-niri`; `profiles/desktop-niri.nix` (enable + greeter.configHome, autoLogin false); `modules/features/desktop-niri.nix` mirroring desktop-hyprland.nix (assertions vs hyprland+gnome 3-way, programs.niri + xwayland + portal gtk check, keyring/gvfs/dconf/polkit/upower + systemPackages sans hyprland bits, greeter compositor.name="niri" with hyprland fallback, push-down `desktop.niri.enable`); extend the 2 existing desktop assertions with niri; `home/niri.nix` (import DMS hm modules, hand-KDL via `xdg.configFile."niri/config.kdl".source = pkgs.runCommand … niri validate`, binds mirrored from home/hyprland.nix:214–245, persistence `.config/dms`/`.config/niri` + first-boot `~/.local/state` check); aggregator edits ×2. QC: git add immediately, nix fmt explicit, `test-suite fast yoga yoga-niri` (proves yoga untouched), suggest→ask, eval checks (xdg.portal, defaultSession=="niri"). Risks: greeter-on-niri least-proven (eval catches enum; fallback hyprland), nixpkgs-niri-25.11-vs-DMS (→ official overlay).

⚠️ Interplay with [[dux-shell-evaluation-plan-2026-11-04]]: that PARALLEL session is executing DMS-on-the-yoga-attr (replacing lucid, branch `dux-shell`). If it lands, the yoga-niri attr's desktop-niri feature coexists fine (per-attr), but lock-at-boot/PAM/keyring wiring assumptions and the `desktop.*` option namespaces must be reconciled — read its state before executing this plan.
