---
name: git-history-rewrite-2026-09-19
description: History rewrite COMPLETE+PUSHED — baseline 240ad11 on main+testing
  (verified on origin), archive/pre-squash-2026-09-19 holds the 797-commit old
  history; bump.yml weekly Sat 02:00 UTC, next run 2026-09-26
metadata:
  node_type: memory
  type: project
  originSessionId: sess_940752f9-d919-47b3-b2be-a4c4aaf51286
---

Executed and pushed 2026-09-19: 797-commit history replaced by orphan baseline `240ad11` on BOTH `main` and `testing` (user explicitly wanted both on the same commit, no divergence churn). Verified on origin after the user's push: origin/main = origin/testing = 240ad11, archive = d3cc2af on remote, local in sync; user's checkout is on `main`. Old history preserved on `archive/pre-squash-2026-09-19` (= `d3cc2af`, the testing∪main-audit union merge; README/REPO_OVERVIEW conflicts hand-resolved: audit rewrite as base + Hyprland/virt/installer facts ported in, jan dropped, mnamer feature row added). Pre-rewrite memories citing old SHAs or "staged on testing/main" resolve through this archive branch.

Folded into the baseline: bump.yml daily → weekly Saturday 02:00 UTC (`0 2 * * 6`) — bumps + 04:00-local host auto-upgrades land a day BEFORE nix-media's Sunday idle-aware reboot (user asked for clean separation from the Sunday build). Weekly cron is LIVE on origin; next run 2026-09-26 02:00 UTC; no daily bot commits anymore.

QC green on baseline: `nix flake check --no-build` (all 4 attrs incl. yoga-gnome), `nixos-rebuild dry-build` yoga + yoga-gnome. flake.lock = testing's (nixpkgs 4c78701); the two then-unpushed origin bot commits (→cf9d2fb) were discarded by the force-push — next weekly bump catches up.

Branch cleanup (user-requested, same day): `ai_slob` + `mikrotik-mcp` deleted on origin, `mikrotik-mcp` + `restore-yoga-security` + `backup/pre-rewrite-0902` deleted locally. Discipline used throughout: containment-check every branch against the archive before `-D`; any branch with commits NOT in the archive gets preserved as an `archive/*` tag first. mikrotik-mcp had ONE such commit (b9604d2, early npx mikromcp experiment, superseded by pkgs/mikromcp.nix) → tag `archive/mikrotik-mcp-npx`, PUSHED to origin on user request. backup/pre-rewrite-0902 had TWO (1a4396d mikromcp promotion, 5837602 audit fixes — pre-rebase versions; patch-ids differ from the landed twins 39b6127/fbb1da6) → tag `archive/pre-rewrite-0902`, LOCAL only (not pushed). Branch list is now minimal: local + remote = main, testing, archive/pre-squash-2026-09-19; the ONLY leftover is `backup_palette` on origin — offered, undecided. Stale `.git/objects/pack/tmp_pack_ygIser` removed.

Open follow-up (status unknown): any latitude/nix-media checkouts break on `git pull --ff-only` after the rewrite (update-safe/auto-upgrade silently no-ops at the pull step — safe failure) — one-time `git fetch && git reset --hard origin/main` per clone. Until then nix-media's Sunday reboot just reboots the running closure. See [[parallel-index-work]] — the mid-session branch switch to testing at 13:07 was detected and the whole rewrite was done ref-only via plumbing until the final guarded reset.
