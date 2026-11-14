---
name: hyprland-lucid-retirement-niri-promotion-2026-11-14
description: EXECUTED+PUSHED — hyprland/lucid/DMS removed from main, yoga =
  niri+Noctalia (yoga-niri attr gone), GNOME backup via yoga-gnome;
  archive/hyprland-lucid branch; font vendored; lean batch landed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_364713f2-914e-4aa7-8050-b0e8d602f0dd
---

Executed 2026-11-14/15 (user approved full plan: promote & drop yoga-niri, commit+push, lean batch, keep local dux-shell branch). Six commits pushed to main:

1. `d09fd75` (now `3812fdc` after rebase) — staged greetd autologin + noctalia-lock-at-boot landed (QC green).
2. `287c9b3` — Google Sans Flex TTF + OFL license vendored to `home/assets/fonts/` (copied from lucid store path at locked rev 2945eab = 1.20.1; deployed font proven byte-identical via home-files tree). This decoupled home/noctalia.nix from `inputs.lucid`.
3. **`archive/hyprland-lucid` branch** cut at the pre-removal tip and pushed — this is the backup for the WHOLE stack (the older `archive/lucid` @ 3388242 only covered 2026-11-01 state; main's hyprland.nix/desktop-hyprland.nix had moved since).
4. `4e8bd09` feat! — the removal: inputs quickshell/dank-greeter/lucid/dux-shell + overlay stage gone, home/{hyprland,lucid,dms}.nix + lucid-patches/-german/-themes/dms-themes + desktop-hyprland feature/profile + quickshell-patches/ + LUCID_RUNBOOK.md + docs/upstream-prs/ deleted (−4904 lines). `yogaArgs.profiles = ["laptop" "desktop-niri"]`, yoga-niri attr deleted. **`desktop.hyprland.monitors` → `desktop.monitors`**, option now lives in home/battery-refresh.nix (set in hosts/yoga/home.nix for every attr; read by home/niri.nix + the daemon). Hyprland battery-refresh backend deleted; selector niri > GNOME. Lucid persistence entries + /var/cache/dms-greeter dropped. kitty lost the lucid-glass include (static 0.93 opacity). theme.nix switch-theme lost the shell-owned branch; darkman gate now noctalia-only; gtk.enable unconditional true.
5. `56842aa` — scripts/docs: update-safe (pins, host list, lucid guard gone), test-suite hosts, README (niri-first, ONE Windows guest), REPO_OVERVIEW (rows rewritten, manual pins now FIVE incl. noctalia pair, retired-stack gotchas compressed but keeping the still-load-bearing systemd mechanics: WantedBy→target-fragment ordering + lock-at-boot After= trap), AGENTS.md.
6. `647a6c9` — lean batch: ghostty options deleted, filesystem.mountOptions deleted (zero setters — mount opts live in disko), uid=1000 pin moved to profiles/laptop.nix (nix-media 1001 untouched), nix-media lost kvm-intel + default-restates.

**Verification evidence:** fast tier green ×4; niri config.kdl AND noctalia config.toml **byte-identical** between archive's `yoga-niri` attr and main's `yoga` attr (built both home-files trees and diffed); battery-refresh niri/gnome daemon derivation per attr verified; uid pins eval-verified; persistence probes clean. VM battery SKIPPED by user decision (host-units-smoke was the only covering test; suggest itself recommended skip).

**Gotchas hit:** (a) CI bump.yml landed a flake.lock bump (e7a6cdc, nixpkgs f1e5c35) mid-session → push rejected → rebased (clean, disjoint files), archive branch force-moved to post-rebase tip so tip = merge-base like archive/lucid. (b) `nix build <store-path>` of an eval-only derivation fails in this sandbox ("no substituter that can build it") — verify daemon contents via the `yoga` one (already realized) or via eval. (c) HM `gtk.enable` default is FALSE — do not drop the line when simplifying conditionals (caught before eval).

**Still pending user-side:** the live switch `nus yoga switch` / `nixos-rebuild switch --flake .#yoga` (machine still on gen 202 noctalia state since Nov 8 — EVERYTHING since then lands with it, now including the promotion; first boot = autologin straight into niri behind the Noctalia lock). Old `.#yoga-niri` attr no longer exists. Rollback: generations until GC / `.#yoga-gnome` / archive branch. Open: sops rekey for latitude/nix-media (retired admin key) + dead `wifi_home_psk`/`wifi_work_psk` in latitude.yaml; Everforest re-theme still plan-only ([[everforest-palette-plan-2026-11-10]]); dux-shell local branch kept but will diverge harder from main now.
