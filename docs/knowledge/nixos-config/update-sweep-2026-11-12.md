---
name: update-sweep-2026-11-12
description: Pkg bump sweep EXECUTED+QC green — commit 991af6b (UNPUSHED);
  opencode v2.2.6 AND v2.2.7 both fail the upstream-flake gate (vendored
  node_modules hash class), pin holds v2.2.4
metadata:
  node_type: memory
  type: project
  originSessionId: session_a14a4e7cc570f507c1dd6eef0c515606
---

Update sweep executed 2026-11-12 (plan approved, VMs skipped per user, committed per user). Commit **991af6b** on main — **UNPUSHED** (nix-media auto-upgrade sees it only after push). QC: `test-suite fast` green (yoga yoga-niri latitude nix-media).

Bumped: nixpkgs 6f06d20→ac588ef (11-08), home-manager 24f2190→6eb2d33, sops-nix 6018281→fe7b422, disko cedd626→1dd30c2 (its "systemd.initrd now default" fix — good pairing with the nixpkgs bump), nixos-hardware 04c6b94→b6ca87f, dank-greeter 45b82d8→83f318b (master; tags now at v2.1.2), spotx-nix e1b2c3c (+SpotX-Bash db0583a), dux-shell stable 7627111→43255a4 (v2.1.2; eval-only on main, dms.enable=false). Vendored pkgs: zcode 3.16.3→**3.17.2**, mikromcp 1.16.0→**1.16.1** (vendored package-lock still matched — npmDepsHash unchanged; hashes fetched via `nix store prefetch-file`, no placeholder round-trip needed).

**opencode: PIN HELD at v2.2.4.** Gate `nix build github:anomalyco/opencode/v2.2.N`: v2.2.7 (fedc6f2) AND fallback v2.2.6 (dc2ffcf) both FAIL — same fetchNpmDeps hash-mismatch class as the skipped v2.2.5 (shipped packaging disagrees with its own lockfile). Recorded in the flake.nix comment. Lesson: my first gate run printed GATE_EXIT=0 through a `| tail` pipe (tail's exit) — read real exits via `> log 2>&1; echo $?`, no pipe. Next sweep: retry v2.2.8+ only.

Untouched per policy (verified still-newest): lucid 2945eab (stable-tags-only blocked — newest tag still v1.20.1, pin sits ahead on 1.20.5.5 beta), quickshell 9b0f339 (still master tip), noctalia v5.4.1, noctalia-greeter v1.7.0, lanzaboote v1.2.0. Riders byte-identical after the nixpkgs bump: niri 26.04, Hyprland 0.55.4, spotify 1.2.90.451 — so the [[niri-dwt-palm-rejection-2026-11-11]] plan facts remain valid. spotify-spotx real-build probe green (no SpotX drift). impermanence/preload-ng heads unchanged (no-op updates).

User steps: `sudo nixos-rebuild switch --flake ~/nixos-config#yoga`; greeter smoke on next boot of the hyprland attr; push when ready.
