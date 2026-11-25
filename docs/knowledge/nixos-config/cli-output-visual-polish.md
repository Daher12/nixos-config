---
name: cli-output-visual-polish
description: User judges CLI tooling by its presentation — plain stacked-line
  output got rejected as "subpar"; show visual mockup options (AskUserQuestion
  previews) BEFORE building any TUI/table output
metadata:
  node_type: memory
  type: feedback
  originSessionId: sess_f4331e5d-e2ef-4f6b-98b4-6c90e46008c3
---

After the mnamer import-overview wrapper went live (2026-11-22), the user's first feedback was purely visual: "the overview is subpar… some visual separations, ascii or similar… some eye candy… thats not how i pictured that" — the underlying logic was fine and unmentioned.

**Why:** for tools the user interacts with directly (overviews, pickers, summaries), readability IS the feature; functionally-correct-but-plain output reads as unfinished to them.

**How to apply:** before building any user-facing CLI table/TUI output, draft 3–4 ASCII mockup variants with realistic data and let the user pick via AskUserQuestion `preview` fields (boxed/tree/grid/glyph-list archetypes worked well; they chose the most "app-like" boxed tree). Bake in from the start: box-drawing chars + pure-`--ascii` fallback, ANSI colors with isatty+NO_COLOR auto-off (piped output must stay clean for harnesses), terminal-width clamp + middle-ellipsis truncation. Related: [[user-communication-style]], [[mnamer-boxed-ui-plan-2026-11-22]].
