---
name: branch-promotion-plan-2026-11-07
description: PLAN ready REVISED 2026-11-11, NOTHING executed (ExitPlanMode
  denied 2026-11-07 + ×2 2026-11-11) — niri-testing→main promotion, dux-shell
  local testbed, lucid archived; 2026-11-11 user change: vps branch stays
  COMPLETELY SEPARATE WIP (no merge, no box interaction); decisions locked
metadata:
  node_type: memory
  type: project
  originSessionId: session_cb5cf762be262e26b48b75372cf6bd4d
---

Status: full plan drafted 2026-11-07, re-analyzed + revised 2026-11-11 after more work landed; ExitPlanMode denied every time → NOT executed. Sits on top of [[branch-commit-squash-2026-11-07]].

User decisions (LOCKED):
- yoga attr on new main flips BACK to lucid (2 lines in profiles/desktop-hyprland.nix:16-17 — verified 11-11 still dms=true; the file's own comment says "flipping these two lines back restores the main-branch shell"). DMS defaults live only on dux-shell.
- Push scope: main + archive/lucid label ONLY (dux-shell stays local-only testbed).
- Delete: noctalia-testing (local), lucid-testing (local+remote), origin 'testing'. niri-testing deleted after verified push.
- **REVISED 2026-11-11: vps branch stays COMPLETELY SEPARATE local WIP** — user: "work in progress, don't know when we proceed". No merge into main, no push, no VPS box interaction. (Supersedes the earlier same-push-vps-merge argument: main has lacked hosts/vps since Nov 1 anyway, so excluding it changes nothing for the box — the earlier "box loses #vps attr" concern only bites on the day vps work resumes/cutovers.) Known conflicts when vps eventually lands: scripts/test-suite host lists + flake.nix attrs.

2026-11-11 state facts:
- niri-testing tip = `8f1e69e` (Nov 9, "foot terminal, energy timeline, launcher and greeter fixes" — commits everything the 11-08 sessions had staged; tree CLEAN, no dirt step needed). Line: 3388242 → 9bf6fe1 → 2ff4f37 → fee3af7 → 8f1e69e.
- **No rebase needed at all** (niri-testing already sits on main tip 3388242): promotion = promote-prep commit + `git merge --ff-only`. SHAs land in main unchanged → dux-shell's base 9bf6fe1 is a literal ancestor → its `git rebase --onto main 9bf6fe1 dux-shell` is low-conflict.
- 8f1e69e dropped the dormant DMS persistence entries (`.config/dms`, `.local/state/dms`) from hosts/yoga/home.nix (greeter's `.config/DankMaterialShell` KEPT — still needed by the lucid-attr DankGreeter) → dux-shell testbed commit must RE-ADD the two dropped entries alongside its dms=true re-flip.
- Everforest check: NO leakage from the denied 11-10 plan — only hit is pre-existing Colloid tweak list `pkgs/colloid-gtk-theme.nix:46` (baseline 240ad11).
- origin/main still 3388242 (for-each-ref last fetch 11-11); next bump.yml window Sat 11-14. Guard: fetch first; if moved, rebase niri onto it (flake.lock conflict → bump's pins + noctalia inputs intact).
- Switch still pending since Nov 8 (gen 202, sudo-blocked): user runs `sudo nixos-rebuild switch --flake .#yoga-niri` — branch labels irrelevant to that build.

Revised mechanics (full plan in ExitPlanMode 11-11): promote-prep commit (profile flip + REPO_OVERVIEW ~4 "niri-testing branch" mentions) → QC `test-suite fast` + one-off `fast yoga-gnome` (5 hosts) → ff main → `git branch archive/lucid 3388242` → dux-shell rebase + amend testbed profile/persistence into one commit (gate: `git diff 9111dad dux-shell` = exactly those deltas; sanity `fast yoga`) → push main + archive/lucid → delete stale branches → memory record + export + trim over-limit MEMORY.md.

Retained key facts:
- **Why main keeps DMS commit 9bf6fe1**: dux-shell flake input is a hard eval dep for EVERY host (modules/features/default.nix → desktop-hyprland.nix:58 imports inputs.dux-shell.nixosModules unconditionally). Stripping = permanent conflicts with dux-shell branch. DMS config double-gated (features.desktop-hyprland.enable AND .dms.enable) = dormant on main.
- VPS autoUpgrade architecture (for the future resumption): `path:/home/<mainUser>/nixos-config#vps` + ExecStartPre `git pull --ff-only` on a clone of the GitHub origin (default branch main). First upgrade after vps lands should be triggered FROM yoga via `nixos-rebuild switch --flake .#vps --target-host root@107.150.20.39 --use-remote-sudo` (nothing-heavy-builds-on-the-box lore, see [[vps-watchdog-exitnode-plan-2026-11-01]]).
- Follow-ups: .sops.yaml creation rules for secrets/hosts/{vps,nix-media-gatus}.yaml (fold into vps resumption); bump.yml auto-extends CI dry-build to yoga-niri.
- Plan-mode sandbox lore: `git status` AND `git --no-optional-locks status` AND `git ls-remote` are blocked as non-readonly; `git log/branch -vv/diff/show/for-each-ref refs\/remotes` work (for-each-ref = stale-but-useful remote tips).
