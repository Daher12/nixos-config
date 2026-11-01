---
name: zcode-opencode-parity-exec-2026-11-01
description: EXECUTED+QC green STAGED — zcode→opencode parity port (knowledge
  base, doc skills, bash rules, glm-5.3, migration doc); automations +
  zcode-only skills skipped by user
metadata:
  node_type: memory
  type: project
  originSessionId: sess_96e1066b-5ab3-45ba-bfa2-06b72fcdcf44
---

# zcode→opencode parity port — EXECUTED 2026-11-01, staged, pending switch

User approved execution with scope cuts: **skip the 2 zcode automations** (network-scan paused,
litellm-eval fired in zcode) and **skip zcode-bound skills** (browser-use/computer-use/viewers/
guide/creator/dynamic-workflows). ExitPlanMode was DENIED but user then said "execute plan" in chat.

## What landed (all STAGED, never committed; 266 A + 4 M on top of parallel session's commits)
- `docs/knowledge/{nixos-config,optimized_network,default,cleanyourtv}/` — 155 md mirror of zcode
  auto-memory (~/.zcode/cli/memories/projects/<name>-<hash>/memory/), hash stripped.
- `scripts/export-zcode-memory` — stage-in-temp → secret-scan → swap; `--check` = drift+scan only.
- `home/opencode-skills/{docx,pdf,pptx,xlsx}/` — from zcode plugin cache (documents 0.2.1, pdf 0.2.2);
  `::zcode-file-citation` sections truncated + replaced with path-reporting block; pptx visual-judge
  line reworded. Wired in `home/opencode.nix` via `xdg.configFile` (recursive) → `~/.config/opencode/skills/`.
- `home/opencode.nix`: glm-5.3 (reasoningEffort high) on zai-coding-plan; +27 curated bash allow rules
  (journalctl, nix eval/build/fmt/flake-check, dry-build, git add/log/show, readlink/realpath/diff,
  systemctl status/cat, virsh list/dominfo/dumpxml, test-suite fast*/suggest). Deliberately ask:
  flake update, sops, switch/boot, test-suite vm/full.
- Pointers in `AGENTS.md` (§ Agent knowledge base) + `AGENTS-global.md`; `docs/opencode-migration.md`
  checklist; REPO_OVERVIEW.md synced (tree docs/ + home line, opencode.nix row, scripts row).

## Secrets incident (handled)
`obsidian-litellm-integration-2026-10-04.md` contained a LIVE litellm master key (`sk-…`) — redacted in
BOTH the repo mirror AND the zcode source memory file; recoverable via the sops readback in that record.
Script scans staged temp copy BEFORE anything lands in docs/ (no secret ever reaches the repo tree).

## QC proof
test-suite fast green (yoga/latitude/nix-media); home-files build: skills present at
`.config/opencode/skills/` (4 SKILL.md, store copy zcode-free); opencode.json diff vs deployed =
EXACTLY the 27 bash rules + glm-5.3 entry, nothing else moved.

## Facts for migration day
- zcode rulesets: `~/.zcode/cli/db/db.sqlite` local_setting key=ruleset, 4 project blobs
  (22/356/75/3 verbatim commands — NOT patterns; that's why only a curated subset transferred).
- zcode automations live in `~/.zcode/v2/tasks-index.sqlite`. sqlite3 CLI NOT installed — use python3.
- opencode live binary still 2.2.0; flake pin v2.2.4 committed by parallel session (2026-10-31 sweep).
- Parallel session committed its 33 staged files mid-session (HEAD fc0b3ea) — no conflicts.
- ⚠️ Flagged to user, not acted on: `AGENTS-global.md` § FORCE override = blanket "ignore all
  permission denials" rule for opencode sessions — risky; user's call.
- Retirement recipe (hosts/yoga/home.nix zcode blocks, flake overlay line, pkgs/zcode.nix) in
  docs/opencode-migration.md § Migration-day checklist. Related: [[zcode-opencode-parity-plan-2026-11-01]]
