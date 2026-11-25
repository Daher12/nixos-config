---
name: mnamer-boxed-ui-plan-2026-11-22
description: SUPERSEDED — EXECUTED same day (see mnamer-scripts-audit-fix
  2026-11-21 ROUND 6): boxed-tree presentation rework for mnamer-tools overview
  tables landed; style A chosen by the user from 4 AskUserQuestion preview
  mockups after calling the live output "subpar"; presentation-only
metadata:
  node_type: memory
  type: project
  originSessionId: sess_f4331e5d-e2ef-4f6b-98b4-6c90e46008c3
---

**SUPERSEDED 2026-11-22 evening — the plan was approved via "execute plan, verify visuals, also consider that the terminal is not always full screen" and EXECUTED; execution record = mnamer-scripts-audit-fix-2026-11-21 ROUND 6** (UI/Box/glyph sets, ANSI isatty/NO_COLOR, --ascii, width clamp 40–110, and the six bugs visual verification caught: trunc-ellipsis overflow, narrow-prompt [y/c/N] tail eaten → compact question variant, piped-input footer-border glitch, library-relative destinations, guessed-not-duplicated-in-skipped, ascii chrome cleaning with TMDb umlauts passing through). Battery B1–B4 green post-rewrite, narrow-56 + ascii-purity + pty-ANSI + piped-clean all verified, final render from the BUILT wrapper. Staged; NOT on box (commit+push+switch).

Original plan record (design spec still accurate):

Trigger: user ran `mnamer-tools kinder-import-overview --guess` live on nix-media (2026-11-22) and rejected the plain stacked-line rendering — "the overview is subpar… some visual separations, ascii or similar… some eye candy… show me what it could look like". Presented 4 mockup styles via AskUserQuestion `preview` fields (⚠️ param name is `preview`, NOT `preview_string` — first attempt failed validation); user picked **A — Boxed tree**.

**Chosen design (style A):** framed outer box `┌── KINDER · incoming/kinder ────── N files ─┐`, tree-connected rows (`├── file` / `│ └─▶ destination [tag]`), per-section glyph headers — `● CONFIRMED` / `◐ GUESSED` / `⚠ COLLISION` / `○ UNMATCHED` — prompt band INSIDE the box footer (`├──…──┤` separator, closing border printed after the answer).

**Spec details:** ANSI colors on terminals only (green confirmed, amber guessed, red collision, dim unmatched; enabled iff `sys.stdout.isatty()` and no `NO_COLOR` env → piped output stays clean/harness-safe); `--ascii` flag swaps to a pure-ASCII glyph set (`++|+-|`, `* ~ ! o`, `->`, `...`); width = `shutil.get_terminal_size((100,24)).columns` clamped 72–120; middle-ellipsis truncation; files as basenames.

**Scope:** `modules/features/mnamer-review.py` ONLY (~120-line renderer block: glyph sets, ANSI helpers, Box builder) consumed by BOTH `import_flow` and `review_lane`/`execute_picks` (candidate lines aligned to box width, colored scores); `--ascii` on argparse; usage text in mnamer.nix gains `[--ascii]`. Purely presentation — the mnamer test-output parser, y/c/N + pick-per-file semantics, and exec paths stay exactly as verified in [[mnamer-scripts-audit-fix-2026-11-21]].

**Planned QC:** offline battery B1–B5 re-run with glyph-updated greps + assert piped output has ZERO ANSI codes + `--ascii` output has zero non-ASCII bytes (`grep -P '[^\x00-\x7F]'` empty); visual sim with real mnamer + tmp configs (unicode + ascii variants; colors via the python-pty harness); fast gate + rebuild + `--help` smoke; VM skip (presentation layer).
