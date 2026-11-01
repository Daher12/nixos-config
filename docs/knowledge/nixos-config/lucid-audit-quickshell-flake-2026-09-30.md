---
name: lucid-audit-quickshell-flake-2026-09-30
description: Lucid full-picture audit 2026-09-30 (verdict SOUND) + APPROVED
  hardening plan handed off as executor TEXT, NOT executed — themes-wipe fix,
  switch-theme EACCES guard, prefer-dark mirror, VERSION auto-derive,
  minQuickshell 0.3.1 floor, quickshell→upstream flake with nixpkgs-unstable
  input REMOVED (single nixpkgs eval); upstream flake facts + QC gates in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_edc95bc4-614e-4fcb-bbd0-9465f970e7ef
---

2026-09-30 plan-mode audit of home/lucid.nix + whole integration surface (3 Explore agents + own file reads).

**Verdict: module logical AND efficient** (build-time patches, laziness-guarded eval gates, content-addressed rsync, single-sourced theme names, deliberate hypridle-name non-collision, KillMode=process live). Staged-but-not-live at audit time: kitty Nord pin + libvirt self-heal (5 files, user's, branch 1 commit ahead).

**Issues found → plan:**
- P1a: support-tree rsync `--delete` (lucid.nix ~336) lacks `themes` exclude → add-theme.py imports in ~/.config/lucid/themes wiped on next activation. Latent (live tree == the 6 shipped). Fix: `--exclude 'themes'` + second `rsync -rt` (no --delete) for themes/.
- P1b: `switch-theme` on lucid host `ln -sfn`s colloid gtk.css over the writable ~/.config/gtk-4.0/gtk.css (carries lucidSync's `@import url('colors.css')`); next lucidSync append writes THROUGH the symlink into the store → EACCES aborts the whole HM activation (2026-09-24 class). Fix: build-time branch in theme.nix skipping the symlink farm under lucid; shell assignments stay INSIDE the else-branch or writeShellApplication's shellcheck fails (SC2034 unused vars) at real-build time.
- P2a: auto-mode wrapper writes gtk-theme-name via envtool but not `gtk-application-prefer-dark-theme` → stale prefer-dark=1 after timer flips light (observed live mixed ini). Fix: `MODE="$mode"` env into the heredoc; add the key to the GTK3/4 dict only (not gtk2).
- P2b: `version = "1.10.5-local"` manual → `lib.trim (builtins.readFile (lucidSrc + "/VERSION"))`.
- P3: doc drift — REPO_OVERVIEW :153 SUPER+Return→SUPER+T, :154 "lucid-testing only" stale (lucid is default via profiles/desktop-hyprland.nix), lucid.nix reload.sh comment (reload keybind disabled in seed; SUPER+R is the launcher's).

**Quickshell coupling (user-driven pivot):** plan v2's floor gate drew "why quickshell 0.2.1?" — my MCP channel-index query was STALE (see [[verify-versions-against-deployed-system]]); real: deployed 0.3.1 (readlink), stable 26.05 has 0.3.0. User directives: remove nixpkgs-unstable (no double pkgs eval), quickshell's own flake is available, supplied docs (quickshell.org, mirror, danklinux.com, AvengeMedia/dank-greeter).

**Final design (v3, APPROVED, handed off as text):**
- flake.nix: DELETE nixpkgs-unstable input; ADD `quickshell = { url = "github:quickshell-mirror/quickshell"; inputs.nixpkgs.follows = "nixpkgs"; }`; dank-greeter follows → "nixpkgs"; overlay attrs → `dms-greeter = inputs.dank-greeter.packages.<sys>.dms-greeter; quickshell = inputs.quickshell.packages.<sys>.quickshell;` (programs.dms-greeter.package = pkgs.dms-greeter keeps working).
- lucid.nix: `minQuickshell = "0.3.1"` + `quickshellChecked` (compareVersions throw, interpolated into the activation comment like stateFilesChecked).
- QC decision gates: `nix eval .#nixosConfigurations.yoga.pkgs.quickshell.version --raw` MUST print 0.3.1, else pin tag `github:quickshell-mirror/quickshell/v0.3.1`; if the follows-build fails (not expected), drop the follows line (scoped own-nixpkgs exception) and report. REAL build (`nixos-rebuild build`, not just dry-build) is required — writeShellApplication shellcheck only runs at build time. Stale nixpkgs-unstable lock node is inert, prunes at next lock rewrite.

**Upstream flake facts (verified from docs + flake/package sources 2026-09-30):**
- quickshell docs: `git+https://git.outfoxxed.me/outfoxxed/quickshell` ≡ `github:quickshell-mirror/quickshell`; `inputs.nixpkgs.follows = "nixpkgs"` marked **"THIS IS IMPORTANT"** ("mismatched system dependencies will lead to crashes"). NO binary cache anywhere → first build per pin bump compiles locally (~10–30 min; greeter is pure Go, fast).
- Upstream flake package `packages.<sys>.quickshell`/`.default`, version hardcoded in default.nix (was 0.3.1); module set identical to nixpkgs' package (qtbase/qtdeclarative/qtwayland/qtsvg — qtmultimedia/qt5compat/qtimageformats in NEITHER, opt-in via `.withModules`; lucid runs fine without them = behavior-preserving switch; deliberately NOT adding extras).
- dank-greeter flake: `packages.<sys>.dms-greeter` (1.6.2, buildGoModule) + nixosModules (module injects greeterPkgs); greeter execs the SYSTEM quickshell (`qs` runtime dep) → **three-way pairing: lucid pin ↔ quickshell pin ↔ greeter — any bump requires smoke-testing shell AND the login greeter at next boot**.
- lucid upstream declares NO quickshell requirement (install.sh PKG_REQUIRED unpinned) → floor is empirical. dms-greeter NOT in stable 26.05. `scripts/update-safe` needs NO edit (excluded inputs are simply unlisted). Only nixpkgs-unstable consumers were flake.nix:49 (input), :57 (dank-greeter follows), :101 (overlay).

**Status: NOTHING executed.** Full verbatim executor handoff (8 edits, ground rules, QC chain fmt→git add→flake lock→version eval→flake check→dry-build→real build→git add flake.lock, do-NOT list) delivered as the final plan-mode message. User post-switch checks: greeter renders after reboot; theme import survives rebuild; switch-theme prints notice + gtk.css import intact; settings.ini theme/prefer-dark consistent after next 08:00/19:00 boundary. Related: [[lucid-buildtime-patches-2026-09-28]], [[plans-for-weaker-executor]].
