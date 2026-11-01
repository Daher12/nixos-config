---
name: spotify-spotx-integration-2026-10-18
description: Spotify (SpotX-patched via spotx-nix flake) integrated on laptops —
  EXECUTED+QC green STAGED, pending switch
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a52d5159-7fa2-440b-97e1-d5d81bff9c30
---

EXECUTED 2026-10-18 + all QC gates green, STAGED (not committed — house rule), pending user switch on yoga + latitude.

- `spotx-nix` flake input (github:SpotX-Official/SpotX-Nix, follows nixpkgs), locked 77b1def / SpotX-Bash d09abef (bot re-pins ~6 h). Manual pin, NOT in update-safe.
- New `modules/features/spotify.nix` (`features.spotify.enable`, `spotxArgs` option): upstream is OVERLAY-ONLY (no NixOS/HM module); overlay applied inside `mkIf` so disabled hosts never evaluate `pkgs.spotify-spotx`. Statix quirk: `spotxArgs = cfg.spotxArgs` in `.override` must be `inherit (cfg) spotxArgs`.
- Enabled in `profiles/laptop.nix` (mkDefault, brave precedent) → yoga/yoga-gnome/latitude, not nix-media. Persistence `.config/spotify` in hosts/yoga/home.nix only (latitude has no impermanence).
- Verified: flake check green on combined index; `p ? "spotify-spotx"` true on all 3 laptop attrs / false on nix-media; persistence entry present; dry-builds green both hosts. NOTE: nix eval of a gated-away attr on a flake prints "flake does not provide attribute ..." (not "attribute missing") — use `--apply 'p: p ? "spotify-spotx"'` for the boolean.
- Post-switch: first launch downloads ~160 MB spotify + runs SpotX patch at build; verify ad-free + login survives reboot (yoga). Lucid media pill picks it up via MPRIS, nothing to wire.
- Gotcha documented in REPO_OVERVIEW § Known Gotchas: nixpkgs spotify newer than SpotX-Bash pin → loud build error → `nix flake update spotx-nix`.
- SCALING FIX (2026-10-19, STAGED pending switch): user reported tiny text + big cursor = CEF client under XWayland at 1x on scale-2 Hyprland output (spotify is CEF/Chromium, NOT Qt — QT_* vars are no-ops; nixpkgs 26.05 = snap repack). Fix = `nativeWayland` option (default true) in features/spotify.nix: runCommand outer wrapper sets NIXOS_OZONE_WL=1 scoped → nixpkgs wrapper hook unsets DISPLAY → CEF auto-detects Wayland, takes compositor scale (GNOME-safe; a hardcoded --force-device-scale-factor=2 would double-scale under mutter + on 1x monitors). Escape hatch: nativeWayland=false = stock XWayland (then Ctrl+= in-app zoom persists in ~/.config/spotify/Users/<login>/prefs as app.browser.zoom-level). Gotchas: runCommand needs explicit `nativeBuildInputs = [ pkgs.makeWrapper ]`; runCommand sets `name` not `pname` (filter evals by name); nix build needs `${drv}^*` not the output path. Fallback recipe NOT taken: `spotify-spotx.override { deviceScaleFactor = 2; }` (nixpkgs first-class knob, XWayland + flag).
