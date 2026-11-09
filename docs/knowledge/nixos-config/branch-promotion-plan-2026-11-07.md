---
name: branch-promotion-plan-2026-11-07
description: PLAN ready, NOTHING executed (ExitPlanMode DENIED) —
  niri-testing→main promotion, dux-shell local testbed, lucid archived; user
  decisions locked via AskUserQuestion
metadata:
  node_type: memory
  type: project
  originSessionId: session_cb5cf762be262e26b48b75372cf6bd4d
---

Status: full plan drafted 2026-11-07, user answered all 3 AskUserQuestion decisions, ExitPlanMode returned "Permission denied" → NOT executed. Sits on top of [[branch-commit-squash-2026-11-07]].

User decisions (LOCKED):
- yoga attr on new main flips BACK to lucid (2 lines in profiles/desktop-hyprland.nix:16-17 — the file's own comment says "flipping these two lines back restores the main-branch shell"). DMS defaults live only on dux-shell.
- Push scope: main + archive/lucid label ONLY (dux-shell stays local-only testbed).
- Delete: noctalia-testing (local), lucid-testing (local+remote), origin 'testing'. niri-testing deleted after verified push.

Plan key facts:
- **VPS pulls main daily**: autoUpgrade = `path:/home/<mainUser>/nixos-config#vps` + ExecStartPre `git pull --ff-only` on a clone of github origin, default branch main → **vps branch MUST merge into main in the same push** or the box loses its #vps attr. First post-push upgrade should be triggered FROM yoga via `nixos-rebuild switch --flake .#vps --target-host root@107.150.20.39 --use-remote-sudo` (nothing-heavy-builds-on-the-box lore, see [[vps-watchdog-exitnode-plan-2026-11-01]]).
- **Why main keeps DMS commit 9bf6fe1**: dux-shell flake input is a hard eval dep for EVERY host (modules/features/default.nix → desktop-hyprland.nix:58 imports inputs.dux-shell.nixosModules unconditionally). Stripping = permanent conflicts with dux-shell branch. DMS config double-gated (features.desktop-hyprland.enable AND .dms.enable) = dormant on main. dux-shell end state = main + 1 commit (lucid-look + re-flip to dms=true).
- Mechanics: commit parallel-session "lockscreen round 3" dirt on niri-testing first → promote-prep commit (profile flip + REPO_OVERVIEW 4 "niri-testing branch" mentions lines 82/142/170/171) → `git rebase --onto vps 3388242 niri-testing` (expected conflict: scripts/test-suite DEFAULT_FAST_HOSTS → union `(yoga yoga-niri latitude nix-media vps)`; vps touched no flake.lock) → verify `git range-diff 3388242..fee3af7 f823dae..niri-testing` → test-suite fast on all 6 hosts → `git merge --ff-only` main → `git branch archive/lucid 3388242` → dux-shell `git rebase --onto main 9bf6fe1 dux-shell` (possible hosts/yoga/home.nix persistence-comment conflict, combine) + amend dms-profile flip into the replayed commit.
- origin/main still 3388242 as of 2026-11-07 (ls-remote verified, no Saturday bump yet); if it moves before push, expect flake.lock conflict.
- Follow-ups listed: .sops.yaml creation rules for secrets/hosts/vps.yaml (needs box host_vps age key) + nix-media-gatus.yaml; bump.yml auto-extends CI to yoga-niri+vps (dry-builds all attrs).
