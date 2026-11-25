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

## ROUND 2 — 2026-11-23 (user: "add new kinder movies + age behind the names")
Kinder library grew 6 → 18 movies (12 imports 11-22/23 via the new mnamer lane; Kinder-Serien still empty). User demanded FLIMMO-sourced ages ("verify with proper source") — **result: the ENTIRE catalog is FLIMMO 5+, incl. Winnie Puuh Honigsüße Weihnachtszeit (ab 5, flimmo.de/besprechung/4471)** → Kleinkinder (2–4) is now an EMPTY landing bucket (intentional; fills only with genuinely-under-5 titles), Größere Kinder (5–7) holds ALL 18, ordered by FLIMMO age. FLIMMO verdicts (flimmo.de/besprechung/…): Winnie Xmas 4471 + Winnie Puuh 2011 4495 + Heffalump 4792 + Känguruland 5616 + Aristocats 1019 + Rabe Socke 1718 + Lauras Stern Traummonster 4883 = ab 5; Pettersson 1602 = 5–6; Mäusepolizei (via medienbewusst.de) + Monster AG 836 + Dornröschen 2092 + Mary Poppins + Ponyo 586 = ab 7. FLIMMO consistently STRICTER than naive estimates — always check before filing. Renames applied to collections AND home sections: "Kleinkinder (2–4)", "Größere Kinder (5–7)" (PATCH title, If-Match: *, 200). Monster AG (tmdb-585) is ONE content item in libs 1+4 (same file double-imported, 2 versions, Silo auto-merged — no dedup concern). Empty collection rows render fine (verified section list). Lore: DELETE /admin/collections/{id}/items/{item_id} needs If-Match too (204).

## ROUND 3 — 2026-11-23 (user: "validate with another source" → CSM cross-check)
Every title double-sourced (FLIMMO + [CommonSenseMedia](https://www.commonsensemedia.org) / Jugendfilmportal / filme.de). Pattern: FLIMMO narrative-comprehension-strict, CSM content-scar-light. 14/18 corroborate ≥5; 4 diverge (CSM ≤4 vs FLIMMO 5–7): Winnie Puuh ×2 (CSM 3+), Heffalump (CSM 4+), Dornröschen (CSM 4+ "sometimes scary" vs FLIMMO 7). USER DECISION: Pooh trio → **Kleinkinder (now 3 titles: 13706 Winnie Xmas, 51162 Winnie 2011, 13682 Heffalump)**; Dornröschen STAYS Größere (fear axis: Maleficent/Drache). Final counts: Kleinkinder 3 / Größere 15 / Neu 18. Standing filing rule: **a title goes to Kleinkinder only if the gentle axis holds — CSM ≤4 (content-based) counts even when FLIMMO says 5; fear/scary-based divargent stay Größere**. CSM values for the rest: Aristocats 5+, Pettersson portal 5, Rabe Socke Jugendfilmjury 5–9, Lauras Stern filme.de 6, Känguruland CSM 6+, Monster AG/Ponyo CSM 5+ (FLIMMO 7), Mary Poppins CSM 6+, Mäusepolizei CSM ~6+ "too dark for preschoolers", Dorie/Baymax/DuckTales/BuckWild/Flow CSM-known 5+/6+/7+ — no flips.
