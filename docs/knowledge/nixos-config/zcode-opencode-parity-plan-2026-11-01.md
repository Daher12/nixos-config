---
name: zcode-opencode-parity-plan-2026-11-01
description: PLAN ONLY (ExitPlanMode DENIED, NOTHING executed) — zcode→opencode
  parity audit + full implementation plan; user intends future migration to
  opencode
metadata:
  node_type: memory
  type: project
  originSessionId: sess_96e1066b-5ab3-45ba-bfa2-06b72fcdcf44
---

User stated 2026-11-01: plans to **migrate from zcode to opencode** and wants same functionality + knowledge in both. Plan-mode audit done (3 Explore agents + opencode docs research); ExitPlanMode DENIED — nothing executed. Recommended path when resuming: full implementation, all staged/never committed.

**Audit facts:**
- opencode already near-fully declarative: flake pin v2.2.4 (live binary still 2.2.0, staged pending switch), HM `programs.opencode` generates opencode.json + global AGENTS.md ← repo `AGENTS-global.md` (context), libstdc++ wrap, MCP nixos(on)/windows-mcp(registered,enabled=false)/mikrotik(off), permissions incl. curated bash allowlist, impermanence 5 dirs, yoga+latitude on, CI `/oc` bot.
- zcode repo side = packaging only (`pkgs/zcode.nix` AppImage 3.16.3, overlay flake.nix:143, yoga desktop entry/mime/persistence).
- zcode machine-local value: 149 memory md files in 4 projects (128 = this repo; MEMORY.md index = distilled layer), ~480 bash allow rules in `~/.zcode/cli/db/db.sqlite` (local_setting, 4 project rulesets), 2 automations in `~/.zcode/v2/tasks-index.sqlite` (Periodic Network Scan hourly PAUSED; LiteLLM gateway eval one-shot ACTIVE due 2026-11-01 — fires in zcode), plugin skills pdf/docx/pptx/xlsx portable (SKILL.md+scripts in `~/.zcode/cli/plugins/cache/zcode-plugins-official/`), browser-use/computer-use/image-search/node-repl/dynamic-workflows/visual-judge = zcode-bound, NOT portable.
- opencode v2.2.x capabilities verified: skills at `.opencode/skills/` + `~/.config/opencode/skills/` (frontmatter `^[a-z0-9]+(-[a-z0-9]+)*$`, folder match, desc ≤1024, loaded via skill tool not slash), AGENTS.md discovery (project root + global + CLAUDE.md fallback), `instructions` config key accepts paths/globs/URLs, headless `opencode run` (--auto; bug #54894: run --agent ignores agent model). opencode machine state: auth.json 5 providers, 249 sessions, no agent/command/skills dirs, no memory feature.

**Plan (all staged, no commit/switch):** (1) knowledge base → repo `docs/knowledge/<project>/` copy of zcode memories + pointer in AGENTS.md + line in AGENTS-global.md + `scripts/export-zcode-memory` re-sync script; (2) document skills → `home/opencode-skills/` + `xdg.configFile."opencode/skills/…"`; (3) automations → HM systemd user units behind `custom.opencodeAutomations.enable` (network-scan timer disabled-by-default, litellm-eval manual oneshot) calling `opencode run`; (4) conservative bash-allowlist merge (~15–30 curated of 480) into permission.bash; (5) add glm-5.3 (high) to zai-coding-plan provider; (6) `docs/opencode-migration.md` checklist (retire list: pkgs/zcode.nix, overlay line, yoga home.nix desktop/mime/persistence/package) + REPO_OVERVIEW sync. QC: git add new files, explicit `nix fmt`, flake check, byte-diff opencode.json, skills in built home-files tree.

Related: [[plans-for-weaker-executor]] (AskUserQuestion went unanswered → proceeded with recommended options), [[obsidian-litellm-integration-2026-10-04]] (the litellm eval automation).
