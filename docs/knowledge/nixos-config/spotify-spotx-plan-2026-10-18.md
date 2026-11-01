---
name: spotify-spotx-plan-2026-10-18
description: PLAN ready, NOTHING executed (ExitPlanMode denied) — Spotify via
  SpotX-Nix overlay on yoga+latitude; new modules/features/spotify.nix +
  spotx-nix flake input + laptop-profile enable + yoga persistence
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a52d5159-7fa2-440b-97e1-d5d81bff9c30
---

PLAN 2026-10-18, NOT executed (ExitPlanMode permission denied after full design). Request: "cleanly integrate spotify + SpotX-Nix to yoga and latitude".

**Design (all decided by repo convention):**
- SpotX-Nix (`github:SpotX-Official/SpotX-Nix`) = OVERLAY-ONLY flake (no NixOS/HM module), build-time `overrideAttrs` patch of official unfree nixpkgs spotify → `pkgs.spotify-spotx`. `allowUnfree` already on per host (lib/mkHost.nix:57). x86_64-linux only. Sole knob: `.override { spotxArgs = [...]; }`.
- New `modules/features/spotify.nix`: `features.spotify.enable` (mkEnableOption) + `spotxArgs` option; config under mkIf applies `nixpkgs.overlays = [ inputs.spotx-nix.overlays.default ]` INSIDE the mkIf (nix-media never evals spotify-spotx) + `environment.systemPackages`. Header needs `{ config, lib, pkgs, inputs, ... }` (inputs via specialArgs — deadnix gate).
- Register in `modules/features/default.nix` (alphabetical, after ./sops.nix).
- Enable: `features.spotify.enable = lib.mkDefault true;` in `profiles/laptop.nix` (brave.nix precedent = exactly yoga+yoga-gnome+latitude, not nix-media).
- Persistence (yoga ONLY): add `.config/spotify` string to `home.persistence."/persist".directories` in hosts/yoga/home.nix (login+prefs+offline cache live there; unpersisted = logged out each boot). latitude has no impermanence.
- flake.nix input after dank-greeter block: `spotx-nix = { url = "github:SpotX-Official/SpotX-Nix"; inputs.nixpkgs.follows = "nixpkgs"; }` + manual-pin comment.
- REPO_OVERVIEW.md sync: features-table row, laptop.nix row, locked-inputs list (~line 246), config-map (~line 592), Known Gotchas entry.

**⚠️ Operational gotcha (the one real risk):** we follow OUR nixpkgs; SpotX-Nix's bot re-pins SpotX-Bash ↔ nixpkgs lockstep every ~6h. A nixpkgs bump (update-safe) can outpace their pin → spotify-spotx build fails loudly "Nixpkgs Spotify X is newer than SpotX-Bash Y" → fix `nix flake update spotx-nix`, retry. Hence deliberately NOT in update-safe's input list.

**QC order:** git add all files FIRST (new file invisible to flake eval until staged) → `nix flake update spotx-nix` → re-add flake.lock → `nix fmt <files>` → `nix flake check` → spot-checks (`nix eval --raw .#nixosConfigurations.yoga.pkgs.spotify-spotx.pname`; nix-media must have attr MISSING; yoga persistence eval contains .config/spotify) → dry-build yoga + latitude. No switch/commit ([[plans-for-weaker-executor]], [[parallel-index-work]] — flake.lock + REPO_OVERVIEW.md already had parallel staged edits).

Spicetify mutually exclusive in practice (builds its own patched client); playerctl/MPRIS need nothing (Lucid pill picks Spotify up natively).
