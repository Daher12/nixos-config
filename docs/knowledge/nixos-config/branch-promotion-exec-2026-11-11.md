---
name: branch-promotion-exec-2026-11-11
description: EXECUTED+PUSHED — niri-testing→main (ff to 680a22a),
  archive/lucid@3388242 pushed, dux-shell = main+1 testbed commit, vps kept
  separate WIP, stale branches deleted
metadata:
  node_type: memory
  type: project
  originSessionId: session_cb5cf762be262e26b48b75372cf6bd4d
---

Executed 2026-11-11. Plan: [[branch-promotion-plan-2026-11-07]] (denied ×3 in plan mode, revised once: **vps stays completely separate** — user decision, timing unknown). This promotion also committed everything that previous records called "STAGED" (through 8f1e69e).

End state:
- `main` = 680a22a, fast-forward from 3388242: 9bf6fe1 (dms eval base — stays, eval dep) → 2ff4f37 (niri trial) → fee3af7 (noctalia stack) → 8f1e69e (foot/energy/launcher) → 680a22a (promote-prep: profile lucid=true/dms=false + REPO_OVERVIEW branch qualifiers). **PUSHED**; ci.yml runs on it now.
- `archive/lucid` = 3388242 (last lucid-primary main) — PUSHED, backup reference.
- `dux-shell` (LOCAL only, not pushed) = main + ONE commit 7a89c95: the old lucid-look port (9111dad) rebased via `git rebase --onto main 9bf6fe1` (clean auto-merge), then amended with the testbed delta — profile flip lucid=false/dms=true + re-added `.config/dms`/`.local/state/dms` persistence (main's 8f1e69e dropped them as dormant; the seed-once activation needs them on the testbed). **Update procedure = rebase that one commit onto a bumped main, nothing else.** QC: `test-suite fast yoga` green (DMS-on eval).
- `vps` = f823dae, untouched local WIP. Cutover when resumed: merge to main + `.sops.yaml` rules (host_vps age key per SOPS_RUNBOOK §3) + box clone check + `nixos-rebuild --target-host` from yoga (nothing heavy builds on the box).
- Deleted: niri-testing (was 680a22a), noctalia-testing (d85a786), lucid-testing (01dcc54, local+origin), origin `testing`. Kept: dms-caelestia-look, backup-palette, archive/pre-squash-2026-09-19, both stashes (incl. pre-split backup).

QC at promotion: `test-suite fast` green on all five main hosts — first lucid validation of the yoga attr since the fork.

⚠️ STILL OPEN: the pending `sudo nixos-rebuild switch --flake .#yoga-niri` (live yoga stuck since gen 202 / Nov 8; agents sudo-blocked — user runs it). Post-promotion the same command deploys the promoted tree — 2026-11-12 the user asked why a switch is still needed after the promotion: explained that branch promotion moves git pointers only and never deploys (the live system is the last ACTIVATED generation, gen 202 predates the Nov 8-9 work — harvest/energy, foot swap, zcode-unmax fix, lockscreen round 3 are all repo-only until switched; `.#yoga-niri` is a flake ATTR, not a branch; no newer generation exists so a reboot alone wouldn't help). Divergence trap: `hosts/yoga/home.nix` persistence comments intentionally differ between main and dux-shell — expect that conflict surface when rebasing the testbed.

Also open at close-out: the `docs/knowledge/` export of this + parallel sessions' records is STAGED but uncommitted (7 files, docs-only — deliberately per never-commit-unless-asked; user informed 2026-11-12, commit rides the next docs commit on their say-so). A dirty tree showing only those knowledge files is expected, not a defect.
