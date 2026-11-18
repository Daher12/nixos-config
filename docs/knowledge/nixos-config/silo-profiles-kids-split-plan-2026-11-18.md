---
name: silo-profiles-kids-split-plan-2026-11-18
description: PLAN (ExitPlanMode DENIED, nothing executed) — Silo wife/kids
  profiles + Kinder mixed library split into two typed kids libraries + Kinder
  smart-collection Home row; user decisions locked, docs-research lore in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e1ac0b0c-2a7c-419e-8aaf-2c506d9fd64d
---

2026-11-18 plan-mode session (follows [[silo-trial-nix-media-2026-11-15]]). User wants: wife + kids profiles, token-usage evaluation for 3 profiles, and a fix for the mixed Kinder library displaying weird in the TV app (split Movies/Series sections, extra button). Full plan built + user decisions locked via AskUserQuestion; ExitPlanMode DENIED — NOTHING executed.

## Locked user decisions
1. **Split `/mnt/storage/kinder` → `kinder/{filme,seren}`** + two typed libraries `Kinder-Filme` (movies) + `Kinder-Serien` (series); mixed `Kinder` library deleted. (User first wanted kinder as second folder on Filme/Serien, then accepted split+2-kids-libs after the trade-offs.)
2. **Kinder row is enough** for parent access — NO second folders on Filme/Serien (dedup risk, kids-profile restriction and auto-collection would die).
3. **No PINs anywhere** (rejected parent-PIN recommendation).
4. wife profile plain; kids = child profile restricted to the two kids libraries.

## Evaluation answers (docs-verified)
- **Token cost of extra profiles ≈ 0**: only CATALOG text is embedded (vectors shared by all profiles); Taste Profiles / Co-Watch / Recommendations are local pgvector jobs. Cost scales with catalog size, not profile count (~100 new imports ≈ <$0.001). Library recreation re-embeds kinder items once ≈ <$0.01. New profiles start generic until history accrues; co-watch gets real pairs (free, better recs).
- **Sammlung ≠ profile replacement**: collection = navigation, profile = separation (progress/recs/restrictions).

## Silo docs lore (siloserver.org + upstream docs/*.md, verified 2026-11-18)
- **Smart-collection rule fields CANNOT filter by genre/age/path** — only title, show_title, decade, runtime, ratings_imdb/tmdb/rt, added_at, release_date, latest_episode_added, last_air_date, last_watched (ops contains/is/gt/in_last…). Rules are `{field,op,value}` in `query_definition.groups`; a smart query CAN name multiple libraries → library scoping is the ONLY auto-selector for a Kinder collection.
- **Library Enabled=off hides from browsing AND skips scans** (would break the media-import pipeline feeding kinder). Delete is async: `DELETE /api/v2/libraries/{id}` → 202 + `GET /api/v2/library-jobs/{id}`.
- **Multi-folder libraries exist** ("You can add more than one folder for the same type") but cross-library overlap/dedup is UNDOCUMENTED; typed library scanning foreign-type files on a mixed root is UNDOCUMENTED (likely garbage/unmatched).
- Mixed classification order: season folder → episode; folder with TMDB/IMDb id → movie; SxxEyy code → episode; else movie. Docs recommend separate typed libraries. Apple platforms show mixed libs under BOTH Movies and Series; Android treats mixed as "Video library".
- Profiles: only the PRIMARY profile manages profiles in GUI; API route `POST /api/v2/admin/users/{id}/profiles` (createProfile: name, is_child, pin — `"pin": null` clears via PATCH); parental controls = per-profile max content rating + max advisory age + hide-unrated + restrict libraries (≥1); admin routes replace household-manager check, no X-Profile-Token.
- Collections API (profile-scoped, docs/collections-api.md): `is_shared`, `include_in_server_collections` (Collections tab), `query_definition`, imports from MDBList/TMDB; synced lists show only titles already in library.
- Home: server-wide rows via Admin > Libraries > Home Section (add collection/rule row; also per-library pages); profiles can hide/rename/reorder; per-profile override via `/api/v2/admin/users/{id}/sections`.
- Embeddings/recommendations docs: "A hosted embedding endpoint receives catalog text from Silo"; model locked after first success.

## Planned execution order (unexecuted)
0 read-only preflight (account id, library shapes, openapi schemas for createProfile/collections/home-sections; filesystem dry-run classify of kinder top-level dirs: series = Season*/S?? subdirs or SxxEyy files) → 1 disable mixed Kinder (Enabled=off) → 2 mkdir kinder/{filme,serien} + mv (ambiguous left for manual) → 3 POST two typed libs (metadata de) + scan + DELETE mixed lib → 4 profiles wife/kids (PATCH restriction or GUI fallback) → 5 smart collection "Kinder" spanning both kids libs, is_shared, as server-wide Home row below Continue Watching → 6 repo: update import-pipeline destination (kinder/filme vs kinder/serien) in hosts/nix-media zsh files, test-suite fast nix-media → 7 verify (recs status green, web UI, TV app; embeddings catch-up re-embeds).
Container mount `/mnt/storage/kinder:/mnt/media/kinder:ro` covers subdirs → NO docker.nix change; Jellyfin untouched during A/B.
⚠️ Known cost: library recreation = new catalog rows → the hand-matched kinder titles (ae/ü/& batch) likely need re-matching in GUI once; old watch progress on kinder items lost.
Lore: plan-mode harness BLOCKS ssh Bash entirely (even read-only curls) — live openapi/psql scans only possible outside plan mode.

**How to apply:** if user reopens, decisions above are locked; follow [[silo-trial-nix-media-2026-11-15]] for admin-API conventions (Bearer ~/.silo-admin-key on-box, If-Match rules, background ssh).
