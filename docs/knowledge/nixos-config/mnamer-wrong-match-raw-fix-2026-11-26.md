---
name: mnamer-wrong-match-raw-fix-2026-11-26
description: Wrong-match case ("12 12 12" show assigned to "Becoming") —
  no_guess only guards zero-hit files; import-overview has NO per-file override
  for matched-but-wrong entries; escape hatch = `mnamer-tools raw --media
  episode --id-tvmaze=84261 [--test] <single path>`; kinder lane has NO raw verb
  (main-config /kinder/ ignore would exclude it); structural fix offered,
  undecided
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ba9cc7bc-d6b5-44d5-aa06-1dce97d319bd
---

Q&A + diagnosis 2026-11-26 (extends [[mnamer-scripts-audit-fix-2026-11-21]]). User hit a WRONG MATCH that `no_guess=true` did not catch: a show literally titled "12 12 12" (Apple TV heist drama, premiered 2026-11-13) kept getting assigned to "Becoming" on every import preview, before any accept. User noticed it in the import-overview table but had no way to correct it there.

**Root-cause shape:** `no_guess` only intercepts ZERO-hit files; a wrong hit sails through as "matched". mnamer's batch mode picks its own best hit from the provider search, so a fragile query re-derails identically every run. Numeric/short titles are the fragile class: live probe — TvMaze `search/shows?q=12 12 12` returns the CORRECT show as top hit (id **84261**, TVDb 450094, score 1.42), but `q=121212` (spaces stripped) returns junk ("1122: For a Happy Marriage") — so mnamer's parse/cleanup of the query, not provider ranking, is what breaks it.

**Tooling gap confirmed:** `review` researches suggestions only for UNMATCHED files; a matched-but-wrong file never enters that bucket, and import-overview's y/c/N prompt has no per-file override. No existing verb can correct it.

**Escape hatch that works today (main lane):**
```
mnamer-tools raw --media episode --id-tvmaze=84261 --test '<one file or folder>'
# verify target, then drop --test; --id-tvdb=450094 equivalent
```
- `--id-*` pins the exact match deterministically (bypasses the search; batch-mode compatible — same mechanism the review tool's exec uses).
- `--media episode` forces the episode pipeline so the directive can't apply to the wrong media type.
- ⚠️ `--id-*` applies to EVERY file in that invocation → target exactly one file/folder, never the lane.
- ⚠️ **No `kinder-raw` verb exists** — `raw` runs the main config, whose `.*/kinder/.*` ignore would exclude a kids-lane path. Kids-lane wrong matches currently have NO escape hatch.

**OPEN:** offered a structural fix (per-line "correct id" action in import-overview, or `kinder-raw`) — user has not decided. Not executed, not staged.
