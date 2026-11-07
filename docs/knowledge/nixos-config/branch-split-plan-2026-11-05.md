---
name: branch-split-plan-2026-11-05
description: PLAN BUILT, ExitPlanMode DENIED (nothing executed) — split the 32-file
  mixed staged bundle (vps+dms+niri, all UNCOMMITTED in main's index) onto branches;
  user decisions: vps→own branch, keep dux-shell+niri-testing names; full mapping + assembly recipe inside
metadata:
  type: project
---

Plan-mode session 2026-11-05 (afternoon): user asked to "split the commits correctly on main/dms/niri branches, vps stuff got mixed up".

**Ground truth discovered (corrects earlier memories):** NOTHING was ever committed to the wrong branch — there are no `dms`/`niri` branches. `dux-shell` and `niri-testing` (and `dms-caelestia-look`, fully merged into main) are pointers at main tip 3388242 (== origin/main, pushed, clean). ALL vps+dms+niri work (32 files, +1928/−75) exists only as ONE staged changeset in main's index — the "STAGED on branch X" phrasing in earlier memories is misleading: the index traveled across branch switches because all branches point at the same commit. Mixing happened in the index, not commits → surgery is index-only, no history rewrite, main untouched.

**User decisions (locked):** VPS work → own new `vps` branch (NOT main — keeps main free until box deployed + gatus secrets verified); keep branch names `dux-shell` + `niri-testing` (flake.nix comments + docs already reference them).

**Layout:** main (untouched) ← `vps` (off main) and `dux-shell` (off main) ← `niri-testing` (ff onto dux-shell then 1 commit). niri HARD-DEPENDS on dms stream: desktop-niri.nix consumes the dux-shell modules imported unconditionally in desktop-hyprland.nix and sets desktop.dms.enable (home/dms.nix option) — niri cannot exist without the dux-shell commit beneath it.

**Stream map (hunk-level, verified):**
- vps: hosts/vps/** (default.nix imports gatus+maintenance+platform+hardware — one commit), scripts/vps-{seed.sh,finish.sh,seed-export.py}, secrets/hosts/{vps,nix-media-gatus}.yaml, hosts/nix-media/ntfy.nix (gatus push + heartbeat), modules/features/vpn.nix (advertiseExitNode, default false = inert), flake.nix vps+vps-install attrs, test-suite vps lines.
- dms: home/dms.nix + dms-themes/grayscale, flake.lock (ONLY dux-shell+dank-qml-common_2+flake-compat_3 renumber, no other revs moved), flake.nix dux-shell input block, home/hyprland.nix (all 6 hunks), home/theme.nix, profiles/desktop-hyprland.nix (lucid=false/dms=true), scripts/update-safe --pin, home/default.nix ./dms.nix import, hosts/yoga/home.nix dms persistence, desktop-hyprland.nix dms hunks (NOT the 2 niri assertions).
- niri: home/niri.nix, desktop-niri.nix, profiles/desktop-niri.nix, features/default.nix, desktop-gnome.nix assertion, REPO_OVERVIEW.md (ALL its hunks are niri — vps never documented), flake.nix yoga-niri attr, home/default.nix niri import+dconf condition, yoga/home.nix niri persistence, desktop-hyprland.nix 2 niri assertions, test-suite yoga-niri in ALL_HOSTS.
- 5 mixed files need per-branch variants (all additive line-blocks): flake.nix, scripts/test-suite (vps and niri edit the SAME ALL_HOSTS line — would merge-conflict if both branches merged), home/default.nix, hosts/yoga/home.nix, desktop-hyprland.nix.

**Assembly recipe (from the full plan, delivered via ExitPlanMode, denied):** safety net = `git stash create` + `git stash store` (captures index without touching it; keep, never drop); per branch: `git reset` → `git checkout HEAD --` non-stream files → `git checkout stash@{0} --` pure-stream files → subtractive Edits of mixed files → selective `git add` → 1 commit per stream. Lossless proof: `git diff vps stash@{0}` shows only dms+niri paths AND `git diff niri-testing stash@{0}` shows only vps paths. QC: `test-suite fast` per branch tip (each layer never evaluated in isolation; vps branch defaults include vps; niri needs explicit yoga-niri host arg). End on main == origin/main, push nothing. VM battery: skip recommended.

**Flagged follow-ups:** .sops.yaml has NO creation rule for secrets/hosts/{vps,nix-media-gatus}.yaml and no host_vps key (decrypt unverified — check before any nix-media/vps switch; SOPS_RUNBOOK territory); REPO_OVERVIEW has no VPS rows (follow-up docs commit on vps branch, kept out for byte-exact split); test-suite DEFAULT_FAST_HOSTS on vps branch only (niri-testing defaults stay yoga latitude nix-media).

Related: [[niri-testing-trial-2026-11-05]], [[dux-shell-eval-branch-2026-11-05]], [[vps-watchdog-exitnode-plan-2026-11-01]], [[parallel-index-work]]
