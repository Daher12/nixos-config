---
name: lucid-hardening-quickshell-flake-2026-09-30
description: Lucid audit fixes EXECUTED + quickshell migrated to upstream flake
  (nixpkgs-unstable input deleted) — staged uncommitted 8 files, QC green, user
  switch/reboot pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_18b64d30-9dca-4698-8262-e8d2c3afd2ad
---

2026-09-30 full lucid audit → plan approved after 3 rounds → **executed same day** (main session, not handed off).

**Audit findings (all fixed):** support-tree rsync `--delete` could wipe user-imported `~/.config/lucid/themes/<id>` (the fix "proposed" in [[lucid-matugen-accent-color-2026-09-28]] is now EXECUTED); `switch-theme`'s gtk-4.0 symlink farm would point gtk.css into the store → next lucidSync append = EACCES activation abort; auto-mode wrapper left stale `gtk-application-prefer-dark-theme=1` after light flips (observed mixed ini); lucidPatched version manual; docs drift (SUPER+Return→SUPER+T etc.).

**Fixes in `home/lucid.nix`:** themes excluded from `--delete` + separate no-delete rsync for `themes/`; `version = lib.trim (readFile VERSION)-local`; envtool write now includes `gtk-application-prefer-dark-theme` (GTK3/4 only, via `MODE` env); `minQuickshell = "0.3.1"` floor gate `quickshellChecked` (lazy-throw, interpolated next to stateFilesChecked in activation comment); reload.sh comment corrected. **`home/theme.nix`:** switch-theme branches on `config.desktop.lucid.enable` — lucid: echo notice, NO symlink farm; assignments live inside the else-branch (shellcheck SC2034 would fail the writeShellApplication build otherwise).

**quickshell migration (user-directed):** `nixpkgs-unstable` input DELETED (was only used for quickshell+dms-greeter overlay + dank-greeter follows). quickshell now from `github:quickshell-mirror/quickshell` (locked rev `41651d7` 2026-09-25, **version 0.3.1 = previously deployed**, no runtime change), `inputs.nixpkgs.follows = "nixpkgs"` (upstream-marked "THIS IS IMPORTANT"); dms-greeter from `dank-greeter.packages` (1.6.2, pure Go), follows repointed to main nixpkgs. ONE nixpkgs eval now; NO binary cache → quickshell compiles locally per pin bump (~5 min on yoga). Stale lock node pruned automatically by `nix flake lock`. `update-safe` needed no edit. Three-way pairing rule (lucid↔quickshell↔greeter, both exec system quickshell) documented REPO_OVERVIEW ~380.

**QC green:** nix fmt / flake check (4 hosts) / dry-build / real `nixos-rebuild build` exit 0 (system `n5lsqh8r…`); built activation grep-verified (floorGate ok + themesSync + stateGate ok + `lucid-source-1.10.5-local`); built switch-theme: guard present, zero `ln -sfn`.

**FINAL: staged uncommitted 8 files 235+/155−** — mine (REPO_OVERVIEW.md, flake.nix, flake.lock, home/lucid.nix, home/theme.nix) + pre-existing parallel work (home/terminal.nix kitty Nord, hosts/yoga/default.nix, modules/features/virtualization.nix) untouched.

**User pending:** switch → reboot (greeter smoke-test!) → verify theme import survives rebuild, switch-theme prints notice + gtk.css import intact, settings.ini consistent after next 08:00/19:00 boundary → commit.

**Lesson:** the nixos MCP channel "info" served a STALE quickshell version (0.2.1 vs real 0.3.1) — user corrected; ground truth = `readlink -f /run/current-system/sw/bin/<pkg>` or eval against the actual lock. NixHub `nix_versions` was accurate.
