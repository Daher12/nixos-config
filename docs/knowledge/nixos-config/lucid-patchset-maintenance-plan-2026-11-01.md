---
name: lucid-patchset-maintenance-plan-2026-11-01
description: SUPERSEDED (executed same day, see lucid-german-dictionary-2026-11-01)
  — Lucid patch-layer maintenance evaluation + user-approved strategy (German dict
  translator, 001 upstream draft, stable-tags-only); evaluation facts + upstream
  PR verification retained here
metadata:
  node_type: memory
  type: project
  originSessionId: session_a8403f5c3853d9d7814d3261856b070e
---

Evaluation of the 19-patch lucid layer (3,116 lines) 2026-11-01, plan mode. ExitPlanMode DENIED → NOTHING executed; full plan text was in the ExitPlanMode call. Burden is concentrated: German cluster 113–119 (~2,280 lines, 73%) re-expressed at 3 of 4 bumps; 001 NixOS paths re-expressed at EVERY bump; perf round 122–127 never rejected. Wiring = `lucidPatched` in home/lucid.nix:44-143.

**User decisions (AskUserQuestion, binding):**
1. German layer → **dictionary translator**: delete 113/114/115/117/118/119, replace with `home/lucid-german/{en-de.json,translate.py}` run in postPatch (zero-replacement dict entry = loud build failure, .rej-equivalent), residual patch `131-german-residual.patch` for non-literal hunks (Qt.locale("de_DE") etc.; 130 reserved by brightness plan). Keep 116 (ordering, not translation). Byte-proof vs current lucidPatched output = acceptance gate.
2. Upstreaming → **only 001** as XDG_DATA_DIRS-based re-expression, draft in docs/upstream-prs/001-xdg-data-dirs/ (patch + PR body, USER submits). Skip 111/129.
3. Bump policy → **stable tags only, opportunistic — but keep running current beta 1.20.5.5 @ 2945eab, do NOT downgrade** (mid-turn user message).

**Upstream facts verified 2026-11-01:** lucid has NO i18n work and zero NixOS/XDG issues/PRs; upstream PR #97 ("choose what System shows in bar") obsoletes our 104 when merged; PR #98 ("cava rests") obsoletes 123; quickshell icon-crash issues (#1007/#1028/#1056/#1079) ALL still open, zero maintainer activity → patch 201 stays; quickshell PR #1049 disk-cache still unmerged → plan [[quickshell-pr1049-diskcache-plan-2026-10-17]] formally ABANDONED (adds engine patch + wrapper complexity).

Also planned: fix 124's doubled `// //` comments (Net.qml/Audio.qml); no patch merging (worse triage, same conflicts); runbook P0 stable-tag gate + #97/#98 watch list; 121/122/124-129 all stay. Related: [[lucid-integration-evaluation-2026-10-13]] (German cluster = recurring tax), [[lucid-buildtime-patches-2026-09-28]] (why seds→patches: loud drift).
