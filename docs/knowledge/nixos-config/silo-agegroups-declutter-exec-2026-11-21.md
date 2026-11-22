---
name: silo-agegroups-declutter-exec-2026-11-21
description: EXECUTED+LIVE — Silo kids Sammlung split into Kleinkinder/Größere
  Kinder manual collections + Neu-in-Kinder 30d smart staging row; old row/collection
  deleted; parent nav-hide GUI step handed to user; API lore in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_78feec07-8333-4002-829e-15dbc4a9923f
---

EXECUTED 2026-11-21 (plan in [[silo-agegroups-declutter-plan-2026-11-21]], user approved "execute plan" + age table confirmed via AskUserQuestion). Follows [[silo-trial-nix-media-2026-11-15]] for API conventions (Bearer ~/.silo-admin-key on-box, backgrounded ssh, jq parsed locally on yoga).

## Live state now
- Collections (all library_id "4", library_ids ["4","5"], visibility "visible"): **Kleinkinder** id 153062506678488081 (manual, Winnie Puuh movie-tmdb-13706, item_count 1), **Größere Kinder** id 153062506728819729 (manual, Dorie/IceAge-BuckWild/DuckTales/Baymax/Flow, count 5), **Neu in Kinder** id 153062506762374161 (smart, query_definition `added_at in_last 30d` + `library_ids [4,5]` INTEGERS, count 6 — ALL titles are <30d so Neu currently duplicates both age rows; ages out naturally ~mid-Dec).
- Home sections (scope home): 0 Continue Watching, **1 Kleinkinder 153062543957462033, 2 Größere Kinder 153062543991016465, 3 Neu in Kinder 153062544007793681**, 4+ the old defaults. Old "Kinder" section 152489402046631881 DELETED; old smart collection 152489315828518857 DELETED (If-Match: *).
- Age assignments (user-reviewed 11-21): Winnie ab~2 (FSK 0); Dorie ab~5 (grenzwertig 4/5); Ice Age Buck Wild + DuckTales-Film ab~5; Baymax + Flow ab~6 (Flow = Beinahe-Ertrinken, wortlos, zu intensiv für Kleine). Future imports: file via GUI into one of the two manual collections; Neu row is the waiting area.
- Kinder profile VERIFIED untouched: library_restrictions_enabled=true, allowed_library_ids ["4","5"], no PIN, max_content_rating "".

## API lore (new since 11-18)
- **GET /api/v2/collections/{id} (viewer route) now REQUIRES X-Profile-Id** (422 without); /api/v2/admin/collections/{id} works WITHOUT it. openapi.json fetches WITHOUT auth: `curl http://localhost:8090/api/v2/openapi.json`.
- **Add collection member = PUT /api/v2/admin/collections/{id}/items/{item_id}** body `{"position":n}` (POST /items does NOT exist; remove = DELETE same path). Sections create: `{"scope":"home","section_type":"collection","title":…,"config":{"library_collection_id":…},"item_limit":30,"enabled":true}` — position assigned via order PUT only (created sections land at 0).
- Sections order PUT: fresh `GET /admin/sections/order` ETag each time (etag string tail mutates), body ordered_ids ONLY (scope/library_id are QUERY params per current openapi), `If-Match` header. DELETE /admin/sections/{id} + DELETE /admin/collections/{id} need `If-Match: *`.
- Smart-collection create payload shape proven live: `{"collection_type":"smart",…,"query_definition":{"sort":{…},"limit":10000000,"match":"all","groups":[{"match":"any","rules":[{"op":"in_last","field":"added_at","value":"30d"}]}],"library_ids":[4,5]}}` — tautology trick ("100y") and integer library_ids both confirmed still required/valid.

## OPEN (user GUI step, ~30s/profile, Phase 2 of plan)
Parent nav declutter NOT done (per-profile preference, admin key can't set it): sign into web app as **dk** and as **Sandra** → Settings → Libraries → hide **Kinder-Filme + Kinder-Serien**. Effect: kids libs leave that profile's navigation; the three Kinder Home rows keep working (soft hide ≠ restriction), so family viewing is unaffected. If a row ever goes empty: revert the hide.

**How to apply:** future kinder imports → wait in "Neu in Kinder" row → user files via GUI into Kleinkinder/Größere Kinder; re-age-tune any time by PATCH /admin/collections/{id} (memberships via PUT/DELETE items paths above).
