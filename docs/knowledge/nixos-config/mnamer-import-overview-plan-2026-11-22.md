---
name: mnamer-import-overview-plan-2026-11-22
description: PLAN (ExitPlanMode DENIED, NOTHING executed) — import-overview /
  kinder-import-overview verbs (+ --guess): table overview incl. skipped files,
  y/c/N proceed, one real mnamer run; extends mnamer-review.py, no new file;
  user decisions locked; QC round 4 of the review tool recorded here too
metadata:
  node_type: memory
  type: project
  originSessionId: sess_f4331e5d-e2ef-4f6b-98b4-6c90e46008c3
---

User request 2026-11-22 (after the review tool landed): "small wrapper for the normal import — lots of files get cluttered. Dry run (no guess) and dry run guess should include an overview table with names and matches INCLUDING skipped files; maybe a question if fine then proceed. All-media dry run (no guess) with overview, all-media (guess) with overview + question to proceed. Same for kinder. That's it — these 3 tools (incl. the review wrapper)."

**User decision LOCKED via AskUserQuestion: guess-variant confirm = y (import confirmed + guessed, exactly what the table showed), c (confirmed only — guesses stay in lane), N (abort); every table row marked CONFIRMED vs GUESSED.**

PLAN (ExitPlanMode denied → ready for "execute plan"):

**Verbs:** `mnamer-tools import-overview [--guess]` (main lane) and `mnamer-tools kinder-import-overview [--guess]` (kinder lane). One implementation shared with review — extends `modules/features/mnamer-review.py`, NO new python file.

**Flow per invocation:**
1. Parse mnamer `--test --batch --verbose --no-style` vs the lane's SAFE config → MATCHED rows (file → destination) + UNMATCHED/COLLISION rows (skipped files shown too).
2. With `--guess`: ALSO parse a test run vs the GUESS config; rows that only "move" under guessing (basename set-difference vs safe-run matched set) = separate GUESSED section — the honest CONFIRMED/GUESSED distinction.
3. One prompt: `import N confirmed[ + M guessed] files? [y/c/N]` (no-guess variant plain `[y/N]`).
4. Execute = ONE real mnamer run over the lane dir (batch): `c`/no-guess → safe config (no_guess can't move guesses); `y` in guess mode → guess config. no_overwrite still guards collisions everywhere.
5. Post: crawl_media before/after counts → "imported X — left in lane Y".

**Changes:** ① mnamer-review.py: argparse += `--mode {review,import}` (default review) + `--guess`; new `import_flow(lane, mnamer, guess)` reusing run_mnamer_test/parse_mnamer_output/fill_sources/crawl_media/rel/eprint; main() dispatches on mode, same repeatable --lane args. ② mnamer.nix: case entries `import-overview)` / `kinder-import-overview)` → `exec python3 <reviewScript> --mode import --mnamer <exe> --lane <lane triple + guess config> "$@"` (extra args pass through → --guess works); usage text. ③ REPO_OVERVIEW.md verb-list sync. `import`/`import-test`/`kinder-*` RAW VERBS UNTOUCHED — media-import stage 3 depends on their plain behavior. Final tool set: media-import (pipeline), import-overview (friendly manual import), review (residue fixer).

**Planned QC:** ast/py_compile; nix fmt; git add; fast nix-media; real toplevel build + `--help` smoke; offline battery with fake mnamer (order-INSENSITIVE case patterns — lore: review passes `--config-path <cfg>` BEFORE `--test`, so `*--test*GUESSCFG*` never matches, match `*GUESSCFG*` alone): no-guess table incl. skipped rows, guess table CONFIRMED/GUESSED split, y→guess-config exec call, c→safe-config exec call, N/EOF→zero calls, empty lane→no prompt; real-mnamer E2E with hand-made tmp configs (matched imports on y, unmatched stays on c, unmatched moves under guessed name on y+--guess); VM skip (same class as prior rounds).

Related: [[mnamer-scripts-audit-fix-2026-11-21]] (all executed fixes + review tool + QC lore; its QC round 4 landed the year-in-query fix, y/c semantics build on that harness).
