---
name: mnamer-wrong-match-raw-fix-2026-11-26
description: Wrong-match case ("12 12 12" show assigned to "Becoming") —
  EXECUTED 2026-11-27: import-overview now screens matched rows (numeric-only /
  low-similarity / year-mismatch flags → amber SUSPICIOUS section, excluded from
  y) with per-row override `<row>:<provider>-<id>` (live preview + immediate move
  via --id-*) and `<row>:ok` escape; kinder-raw verb added; --id-*+--test combo
  LIVE-VERIFIED; battery 38/38 + real E2E proven; staged, fast green, switch
  pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ba9cc7bc-d6b5-44d5-aa06-1dce97d319bd
---

Wrong-match case 2026-11-26 (extends [[mnamer-scripts-audit-fix-2026-11-21]]): a show literally titled "12 12 12" (Apple TV heist drama, premiered 2026-11-13, TvMaze id **84261**, TVDb 450094) kept being assigned to "Becoming" on every import preview. Root cause: `no_guess=true` only intercepts ZERO-hit files — a wrong hit sails through as "matched", and mnamer's batch pick re-derails identically every run. mnamer's query parse (not provider ranking) is what breaks: TvMaze `q=12 12 12` → correct top hit; `q=121212` → junk.

**EXECUTED 2026-11-27** (user: "execute plan" after 2× ExitPlanMode denial + source-level validation pass). ALL STAGED UNCOMMITTED, `test-suite fast` GREEN (yoga latitude nix-media), NOT on box (needs commit+push+switch).

## What landed

1. **`parse_title_tokens(name) -> (keep, year, stem)`** in mnamer-review.py — query_variants' normalization pipeline extracted; query_variants uses it byte-identically. ⚠️ The refactor initially changed the "or raw stem" fallback to return the name WITH extension (parse_title_tokens reassigns its own local) — caught by unit probe, fixed by returning stem as third element.
2. **`flag_suspicious(rec, roots)`** — three cheap flags on matched rows: numeric-only/unparsable parsed title (fires only when the MATCH is alphabetic or unverifiable — numeric→numeric like "1917"→"1917" rides), similarity < 0.35 (existing score() with year bonus, best of cleaned-title and separator-normalized-stem ratio), movie year mismatch (filename vs destination year). Matched title/year sliced from the destination via `library_roots(lane["config"])` (movie_directory/episode_directory read from the lane's own generated config JSON; first dest component below root, movies strip trailing `(yyyy)`; assumes module-default format templates — custom formats yield no verdict and ride). Known false-positive class: wholly-localized titles ("Frozen"→"Die Eiskönigin") and low-ratio alias matches flag too — `<row>:ok` is the escape.
3. **Import flow rework**: matched rows split bulk/suspicious; amber `SUSPICIOUS (n)` section (⚠ collision glyph) with reason sub-lines; ALL matched rows numbered (bulk 1..k, suspicious k+1..n — numbers stable across overrides, guessed rows unnumbered). Prompt loop: y/c/N/EOF meaning unchanged; `<row>:<provider>-<id>` (tmdb|tvdb|tvmaze; bare id = lane episode_api on series, movies need explicit provider), `<row>:ok` (moves flagged→bulk). Override = per-file `--test` preview with the id directive + line-based accept → **immediate** per-file exec `[mnamer --config-path <cfg> --no-style --id-<prov> <id> -- <source>]` (accept IS execution; final N only governs the bulk). Bulk run passes EXPLICIT accepted sources (never the lane dir — flagged rows must not be swept back); empty source list SKIPS the run (mnamer without targets scans the CWD). Guess mode: y = bulk+guessed under guess config, c = bulk under safe config.
4. **`kinder-raw` verb** in mnamer.nix (mirrors raw with kinderArgs) — closes the kids-lane escape-hatch gap. Usage text documents the new prompt answers.
5. **Pre-existing `Box._top` off-by-one FIXED**: fill forgot the decorative `─` after the corner → title border rendered 1 char wider than the frame (invisible at 100 cols, exposed at 56).
6. REPO_OVERVIEW mnamer.nix row synced (keep-in-sync rule).

## Verification (all green)

- **Offline battery 38/38** (fake mnamer, plain pipes, /tmp/mnamer-qc): y → bulk only safe sources; force+accept → preview + per-file exec exact-argv; decline → nothing; :ok → row rides bulk; all-flagged+N → zero exec; forced-only → no bulk call; movie bare-id hint; guess y/c config selection; ascii purity; piped no-ANSI; 56-col no overflow. Battery bugs caught: num_map inversion (number→id instead of number→rec → TypeError), cfg.json substring-matching guesscfg.json.
- **Unit probes**: query_variants byte-compat (Dornroeschen/1917/Blade Runner 2049/Fireman Sam cases); 11 suspicion flag cases right (wrong-match fires, correct numeric/alias/umlaut matches ride).
- **Real E2E (mnamer 2.6.0 + live TvMaze, /tmp/mnamer-e2e)**: plain --test wrong-matches "12.12.12.S01E01.1080p.mkv" → "Firefly Lane" (the live failure class); **`--id-tvmaze 84261 --test` WORKS** (was the unproven combo — id pins "12 12 12" in test mode, no fallback needed); script flow `1:tvmaze-84261 → y → N` moved the file to `shows/12 12 12/Season 01/…` while final N declined everything else; y-bulk moved 1917 correctly while the flagged file stayed. Hand-made E2E cfg must include the module's episode_format or destinations come out flat (matched_title still worked either way).

## Lore

- `--media` flag was DROPPED from the plan's preview/exec argv — mnamer auto-detects per file; the per-file + id-directive shape is the SIM-2-proven one.
- Reason strings show `parsed '<title>' vs matched '<title>' (n%)` — the % is the max(cleaned, normalized-stem) ratio.
- python3 is absent from the agent sandbox PATH → use `nix build nixpkgs#python3` for batteries; mnamer attr is `nixpkgs#mnamer` (NOT python3Packages.mnamer).
- Escape hatch outside the prompt (unchanged): `mnamer-tools raw --media episode --id-tvmaze=84261 [--test] <one path>` / now `kinder-raw` for kids; `--id-*` binds to EVERY file of an invocation — one file per call.

**OPEN:** commit+push+switch nix-media to reach the box; then real-lane `import-overview` on the "12 12 12" file (should flag → `1:tvmaze-84261` → fixed in-prompt).
