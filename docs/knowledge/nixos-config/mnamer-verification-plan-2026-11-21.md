---
name: mnamer-verification-plan-2026-11-21
description: mnamer/kinder import failure diagnosis + fix plan 2026-11-21 — PLAN
  ONLY (ExitPlanMode permission denied), NOTHING executed; root causes
  source-verified against mnamer 2.6.0 upstream code
metadata:
  node_type: memory
  type: project
  originSessionId: sess_f4331e5d-e2ef-4f6b-98b4-6c90e46008c3
---

User report 2026-11-21: kids imports match nothing at all; normal imports made junk in libraries "even though -safe were used" (AskUserQuestion answers: kinder = "Runs, matches nothing"; normal = "Junk in libraries"). Diagnosis session verified against mnamer **2.6.0 source** (exact nixpkgs version — `frontends.py`, `target.py`, `utils.py`, `providers.py`, wiki). Plan delivered via ExitPlanMode → **PERMISSION DENIED, NOTHING executed**. Refactor offered by user; recommendation = targeted fixes, NOT rewrite (architecture sound).

**Root causes (all source-verified):**
- **P1 kids "matches nothing"**: default `episode_api` = **TvMaze — passes NO language param, not localized** (providers.py). Kids content = German series scene names ("Feuerwehrmann.Sam") vs tvmaze English titles ("Fireman Sam") → 0 hits always. Adult shows work because downloaded as English scene releases. **TVDb honors language=de in search AND ships a bundled default API key** (`E69C7A2CEF2F3152`, env-overridable) — no secret needed, just set `episode_api: "tvdb"`. Plan: PER-LANE provider (main keeps tvmaze so future episodes keep landing in existing English-named series dirs — global switch would create duplicate German series folders; kinder gets tvdb). Kids movies via TMDb (localized) fail only on ae/ue/oe translits = hand-matching residual.
- **P2 junk in libraries**: mnamer batch mode with 0 API hits falls back to **filename-parsed metadata** (`match = matches[0] if matches else target.metadata` in frontends.py) — moves/renames unmatched files on guesses. `features.mnamer.noGuess` defaults false → orchestrator's plain `import`/`kinder-import` verbs run WITH guessing; only manual `-safe` verbs were protected. Fix: noGuess default true (safe-by-default everywhere).
- **P3 functional Nix bug**: `mkSettings` ends `json.generate "mnamer.json" {…} // extraSettings;` — the `//` merges onto the **derivation returned by json.generate**, not the inner settings attrset → **extraSettings NEVER reaches the JSON file** (silently; merged attrset still coerces via outPath so it evals+runs). Host's `hits = 8` has never been applied. (Also `hits` is inert in batch mode anyway — only interactive selection uses it.)
- **P4 kinder leak**: main config recurses over the whole lane incl. `incoming/kinder` with no exclude → leftover kinder files get pulled into main movies/shows after partial kinder imports (decline-guard only covers declined, not partial). Verified in utils.py: **`ignore` regexes match the FULL ABSOLUTE PATH** (`re.search(pattern, str(path), re.IGNORECASE)`), so `".*/kinder/.*"` in the MAIN config only = clean exclusion. Orchestrator comment "mnamer has no exclude" is FALSE.
- **P5 orchestrator**: `kinder_imported=$kinder_before` miscounts (mnamer skips exit 0); stage_extract only extracts lane top + FIRST-level subdirs → folder-shaped kinder releases (`kinder/<Release>/*.rar`) never extracted → silent kinder skip.

Minor: `^RARBG.*` ignore is dead (anchored at start of absolute path — paths start with `/`). CLI spellings all correct for 2.6.0 (`--recurse` not `--recursive`, `--media`, `--config-path`, `--no-style`, `--no-guess`); config keys snake_case; slashes in `*_format` are fine (destination split on separators, `mkdir(parents=True)`); `replace_before/after` are config-only keys (and substring replace makes ae→ä translit maps DANGEROUS — "Michael" → "Michäel").

**Planned changes (not executed):** mnamer.nix — fix extraSettings merge inside generate; noGuess default true (keep -safe verbs as redundant aliases, NO guess escape-hatch verb); per-lane episodeApi/kinderEpisodeApi options; main-config-only kinder ignore; fix RARBG pattern; new kinder-path/kinder-dump debug verbs. media-import.zsh — kinder after-count delta, lane counts prune kinder, extraction+prune extended to depth 2, stage-3 comment fix. REPO_OVERVIEW sync. Verify: fast nix-media + REAL toplevel build (writeShellApplication shellcheck not run by dry-build) + dump/kinder-dump content asserts; VM SKIP (no mnamer coverage). User-side: kids sample in incoming/kinder → `media-import --test` expect TVDb German matches. Watch: TVDb bundled-key rate limits; revert = flip kinderEpisodeApi back.

Links: [[media-import-orchestrator-2026-11-17]], [[nix-media-media-import-workflow]], [[silo-trial-nix-media-2026-11-15]], [[silo-deleted-movie-resurrection-2026-11-18]].
