---
name: spotify-cache-persistence-2026-11-01
description: EXECUTED+QC green STAGED — spotify logout root cause = unpersisted
  ~/.cache/spotify (config dir was persisted since 10-18 and NOT the problem);
  pending switch + deliberate reboot verify
metadata:
  node_type: memory
  type: project
  originSessionId: session_d3c54a820d5edbd88ab4742b4509bd86
---

Spotify "logs out every reboot" on yoga — executed fix round 2026-11-01.

**Diagnosis (surprising):** `~/.config/spotify` (autologin.blob + saved_credentials) was ALREADY persisted since the 2026-10-18 integration (`hosts/yoga/home.nix`), bind mount active in booted gen, files provably survived the 11-01 10:05 boot — yet a re-login happened anyway (per-user dir `ninu1245-user` recreated 07:49 that morning, abandoning the old `31ttui…-user` hash-named dir). Root cause = the only unpersisted spotify state: `~/.cache/spotify` — prefs point `storage.last-location` into it; client treats wiped cache as a new device → login screen despite valid persisted blob. Keyring ruled out (persisted + PAM-unlocked).

**Fix:** added `".cache/spotify"` next to `".config/spotify"` in `home.persistence."/persist".directories` (hosts/yoga/home.nix), comment rewritten. Staged, `nix fmt` clean, yoga dry-build green, `nix eval` probe shows both entries. Latitude unaffected (no impermanence), nix-media has no spotify.

**Pending:** user switch + one deliberate reboot to verify (closes the never-done "login survives reboot" checklist item in docs/knowledge/nixos-config/spotify-spotx-integration-2026-10-18.md). If it STILL logs out after that: suspect spotx client-bump blob invalidation (spotx-nix bot re-pins ~6h; `nix flake update spotx-nix` bumps spotify → one re-login per bump, not per reboot; check `app.last-launched-version`).

⚠️ Caveat told to user: `.cache/spotify` now grows persistently (streaming cache) — same tradeoff as `.cache/quickshell`/`.cache/cliphist`.

**Lore:** flake eval/checks read the WORKTREE content of tracked files, not the git index (AGENTS.md's "reads from the index" phrasing is imprecise). Consequence: a parallel session's unstaged mid-flight edits DO surface in `nix flake check` — my `test-suite fast` run failed nixfmt on the Lumen session's unformatted unstaged `modules/features/desktop-hyprland.nix` (GI_TYPELIB_PATH addition), not on my file; HEAD's version formats clean. See [[parallel-index-work]].
