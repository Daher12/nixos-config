---
name: branch-commit-squash-2026-11-07
description: All three eval branches committed+squashed 2026-11-07 —
  niri-testing fee3af7 (whole Noctalia pile), vps f823dae + dux-shell 9111dad
  (auto checkpoints squashed in, lossless-proven); split audit CLEAN; squash
  lore + topology facts
metadata:
  node_type: memory
  type: project
  originSessionId: session_cb5cf762be262e26b48b75372cf6bd4d
---

EXECUTED 2026-11-07 (user command: "git commit, squash if needed for all branches, analyze the split"). QC before committing: `nix fmt` + `scripts/test-suite fast` green (yoga yoga-niri latitude nix-media — yoga-niri now in DEFAULT_FAST_HOSTS).

**Final tips (nothing pushed):**
- `niri-testing` = `fee3af7` "feat(niri): daily-drive stack — Noctalia shell swap, rice polish, battery niri backend" (46 files, +2289/−322) on `2ff4f37` → `9bf6fe1` (feat dms) → main 3388242. The WHOLE staged pile (noctalia swap + lockscreen rounds + rice polish ×5 + cursor 32 + battery niri backend + scripts + REPO_OVERVIEW + knowledge archive incl. the `docs/knowledge/1793831…/` topic-id dir — legit mirror of the VPS-install session's project, Feishu-topic id as dirname) went in as ONE coherent commit.
- `vps` = `f823dae` = d34fbe2 + checkpoint 4bd2140 squashed (seed-export topo logging + refuse-empty-graph guard). Single clean feat(vps) on main.
- `dux-shell` = `9111dad` = checkpoints 149bed6+cbe9929 squashed + reworded "feat(dms): port the lucid look onto DMS — config.d drop-in + blur layer rules" (+231: config.d drop-in, fonts, frost values, `^dms:` rules, grayscale warning/info keys), on `9bf6fe1`.

**Split audit verdict: CLEAN.** Every commit's file set matches its branch; the auto "chore: checkpoint before switching to X" commits were correctly sorted by branch (only their messages were garbage). Topology facts: (1) NOT a full stack — `vps` grows independently off main; niri-testing forked from 9bf6fe1 BEFORE the dux-shell checkpoints, so it carries DMS base wiring but NOT the lucid-look port (intentional — niri went Noctalia). (2) Pre-baked merge conflicts for the main reconciliation: `hosts/yoga/home.nix` persistence comments edited divergently (DMS wording on dux-shell, Noctalia dirs on niri-testing) + test-suite/update-safe host lists grew on two branches each. (3) OPEN: `.sops.yaml` creation rules for secrets/hosts/{vps,nix-media-gatus}.yaml still missing — fix before vps merges or switches.

**Squash lore (reusable):** pattern = `git checkout <branch> && git reset --soft HEAD~1 && git commit --amend --no-edit` (fold into parent, keeps author date). ⚠️ TRAP hit: after `reset --soft HEAD~1`, plain `git commit -m` creates a NEW commit instead of amending — squashing N commits into one = `reset --soft HEAD~N` then one commit (`git commit -C <old>` reuses message but ALSO its author date — re-amend with `--date="<original>"`). Lossless proof: `git diff <old-tip> <branch>` empty. Both rewritten branches are local-only (no upstream) — safe. `git commit -C` on a commit I just created gives NOW as author date; restore with --date.

Related: [[branch-split-vps-dms-niri-2026-11-06]], [[shell-strategy-converge-niri-noctalia-2026-11-07]], [[dms-lucid-look-port-plan-2026-11-06]].
