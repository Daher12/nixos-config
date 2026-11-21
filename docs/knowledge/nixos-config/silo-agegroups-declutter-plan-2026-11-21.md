---
name: silo-agegroups-declutter-plan-2026-11-21
description: PLAN (ExitPlanMode DENIED, NOTHING executed) — Silo kids Sammlung
  split into 2 age-group collections + "Neu in Kinder" staging row + soft
  nav-hide of kids libs for parents; user decisions locked, Silo docs lore
  verified 2026-11-21
metadata:
  node_type: memory
  type: project
  originSessionId: sess_78feec07-8333-4002-829e-15dbc4a9923f
---

Follows [[silo-trial-nix-media-2026-11-15]] (FAMILY SETUP 11-18: libs 1=Filme 2=Serien 4=Kinder-Filme 5=Kinder-Serien; profiles dk primary / Sandra 25f7461b / Kinder cc7de44c restricted ["4","5"]; smart collection "Kinder Sammlung" id 152489315828518857, Home section id 152489402046631881). 2026-11-21 plan-mode session, ExitPlanMode permission denied — NOTHING executed.

## Locked user decisions (AskUserQuestion)
1. KEEP separate kids libraries (merge of kinder folders into Filme/Serien REJECTED — user explicitly chose against merging; merge would shift kids boundary to metadata-based FSK/advisory ceilings + re-match + progress loss).
2. Hide kids libs from BOTH parents = SOFT per-profile nav-hide (not hard restrict) — user's follow-up "are the kids movies then totally unavailable?" answered: NO, soft hide keeps them reachable via Kinder Home rows for family viewing.
3. Age groups = 2: "Kleinkinder" (~2–4) + "Größere Kinder" (~5–7), MANUAL collections. FSK REJECTED as the axis (user agreed with reasoning): smart collections can't filter by rating anyway → FSK gives zero automation; kids content is uniformly FSK 0/6 → can't split within it. Recommended-watching-age (FLIMMO/Common Sense Media) chosen instead — matches Silo's own advisory-age concept.
4. Age rows REPLACE the all-in-one Kinder Sammlung row + add smart "Neu in Kinder" staging row (added_at in_last ~30d) where new kinder imports wait for manual filing.

## Silo docs lore (siloserver.org, verified 2026-11-21)
- **Primary profile can NEVER be hard-restricted** ("Restrict libraries" narrows only non-primary profiles; primary keeps all account libraries). Workaround (docs-verified): **Settings → Libraries per-profile nav-hide** — and /docs/preferences confirms Settings pages (Playback/Subtitles/Home Screen/etc.) are PER-PROFILE preferences, so dk's hide does NOT affect Sandra/Kinder profile on the same account.
- **Max content rating**: "compares recognized ratings across national systems using viewer ages and rating tiers" (FSK-normalized; value list not in docs — check live). **Max advisory age**: 1–21, from advisory providers (Common Sense Media example), "fills in over time", episodes inherit series' age; both limits stack. Server-wide "Titles with no age rating" (Admin→Libraries→Settings→Maturity limits) default = hide from ceiling-profiles.
- Hard restrictions are enforced server-side (no reach via deep link, search, person page, stream URL). Soft nav-hide = navigation preference only, rows keep working (expected per docs; verify at execution).
- **Multi-folder libraries documented** ("add more than one folder for the same type") — merge was technically possible with zero nix changes (mount already covers /mnt/media/kinder) but rejected.
- Collections: 3 types manual/smart/synced-list (MDBList + any public TMDB list, sync hourly→monthly); shelves per library (drag-drop, rename, pin-to-start) in Admin→Libraries→Collections; any collection addable as row on Home or library page; collection auto-respects profile restrictions ("does not appear for a profile that can open none of its titles"). Deleting a collection lists its rows.
- Smart-collection rule fields STILL not enumerable from docs; 11-18 live list (no rating/genre/path) assumed current — preflight re-checks via openapi since :latest refreshes weekly (Sun 03:00).

## Planned execution (unexecuted)
Phase 0 read-only preflight (ssh blocked in plan mode — run outside): libraries/profiles/sections/collection state; openapi re-verify query fields + collection POST schema (is_shared, include_in_server_collections) + in_last value format; kinder catalog inventory. Phase 1: create Kleinkinder + Größere Kinder manual collections (X-Profile-Id = dk profile UUID) + Neu in Kinder smart (library_ids [4,5] as INTEGERS — the standing 422 trap) + added_at in_last 30d; title→group table from FLIMMO/CSM ages USER-REVIEWED before writing memberships; delete old section 152489402046631881 + collection, PUT /admin/sections/order. Phase 2 USER GUI step (~30s/profile): web app signed in as dk and as Sandra → Settings → Libraries → hide Kinder-Filme + Kinder-Serien. Phase 3 verify (rows/counts/kids profile untouched). ZERO nix changes → no test-suite needed.

**How to apply:** if user reopens, decisions above are locked; follow [[silo-trial-nix-media-2026-11-15]] for admin-API conventions (Bearer ~/.silo-admin-key on-box, If-Match, backgrounded ssh) and [[live-mutation-needs-confirm]].
