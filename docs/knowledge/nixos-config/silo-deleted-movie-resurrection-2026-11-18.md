---
name: silo-deleted-movie-resurrection-2026-11-18
description: "Deleted-from-HDD movies still playable in Silo = mnamer
  movies-safe RE-IMPORT; fix + API pagination lore in file"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_2e7ed9b5-3c21-4a8c-b9f9-a4a022fd7eeb
---

2026-11-18 incident, DIAGNOSED+FIXED (see [[silo-trial-nix-media-2026-11-15]] for API conventions). User deleted movies from `/mnt/storage/movies` on the HDD; Silo still played them "even after rescanning". NOT a Silo defect — the movies came BACK: user ran `mnamer-tools movies-safe` at 17:38 that day, which moved a downloads-area batch (incl. Die Olsenbande 1968, Ente Auf Orange 1975, BTTF I–III, Ducktales, Die Odyssee…) into the library. Realtime inotify ingest re-imported+matched each within seconds (per-dir scoped scans in docker logs). Source copies in the lane were consumed by the move, so no re-resurrection.

**Why:** deleting a library file ≠ deleting the media — mnamer wrappers (movies-safe/shows-safe/import*) scan `$downloads` = the lane `/mnt/storage/downloads/incoming` and MOVE anything in there into the library. A title surviving in the lane (rar or extracted) resurrects on the next import run. Silo mounts are `:ro` (docker.nix) so web-UI deletes can never delete files either — removals happen on the host filesystem only.

**How to apply:** "deleted but still playable" in Silo/Jellyfin → check (1) files still on disk? (`stat` ctime = when it landed — move/rename bumps ctime, preserves mtime), (2) shell history for an import run (zsh EXTENDED_HISTORY epochs), (3) `.Trash-*` dirs (file-manager deletes). Fix pattern: `mv` to quarantine `/mnt/storage/downloads/removed/` (outside lane + all library roots; movies-safe scans only the lane) + `rmdir` empty movie dirs; Silo realtime scanner reconciles "scope no longer exists" and prunes rows automatically — no manual scan or API delete needed. Verify via full catalog paging: 0 title hits = gone.

API lore: `GET /api/v2/admin/catalog/items?library_id=1` (admin, Bearer) → `{items[], page{next_cursor,has_more}}`; **limit ≤ 200** (422 otherwise); pagination param is `cursor` with the opaque next_cursor value (page/page-number rejected: unknown_parameter / invalid_cursor); item rows carry content_id ("movie-tmdb-N"), status, added_at, versions[] but NO file path (paths come from Silo UI "Dateipfad" or /admin/items/{id}/files). jq is NOT on nix-media — paginate locally on yoga. Plan-mode blocks ssh entirely (even read-only); foreground ssh stalls silently → run_in_background.
