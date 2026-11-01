---
name: docs-comment-hygiene-pass-2026-10-18
description: Repo-wide comment+docs hygiene pass EXECUTED+QC green STAGED — 33
  files, runbook withModules trap fixed, new REPO_OVERVIEW pins section,
  install.sh uid bug fix (real gids 1001/982 not 1001/1001)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_4f5fc882-9b0c-4960-a17f-aaf84af5b0ab
---

EXECUTED 2026-10-18, QC green (flake check + yoga/nix-media dry-builds + bash -n), STAGED not committed (on top of 44b405f+0b8a515+693652b).

What was done:
- **33 files**: comment cleanup per 3-agent audit (stale instructions, tombstones, DMS narrative, dup stories, what-banners), 4 approved code fixes, docs sync.
- **Dangerous runbook fix**: LUCID_RUNBOOK §5 Qt-module remedy said `withModules [...]` — would silently drop the 201 engine patch (passthru closes over original wrapper). Now says: add module to replicated wrapper's buildInputs in the flake overlay, ⚠️ never withModules. Appendix B quickshell rev → 2b4501a (2026-10-18).
- **New REPO_OVERVIEW § "Manual Pins & Manual Packages"** (line ~256): table of all 6 locked inputs (lucid/quickshell/dank-greeter/spotx-nix/opencode/lanzaboote) with why-held + bump procedure + mikromcp recipe. README/AGENTS point here.
- **install.sh uid fix**: hardcoded 1000:1000 chown → eval `users.users.<u>.uid`/`.group`/`groups.<g>.gid` from pinned flake. **Audit's "nix-media gid 1001" was WRONG — real: uid 1001, gid 982 (nfsAnonGid); yoga/latitude group gid = null (first-boot alloc) → chown uid-only there (`chown "uid:"` syntax preserves backup gid).**
- Other code fixes: biweekly-reboot→weekly-reboot rename, yoga local-passwords tmpfiles rule deleted, .Trash-1000/ deleted, nvidia-disable statix note dropped, commented-out initcall_blacklist + configurationLimit removed (Plymouth hint folded into initrd block).
- Docs accuracy: README hibernation claim → WORKING; README docs table + LUCID_RUNBOOK row; REPO_OVERVIEW :144 withModules rewrite, lucid pin v1.20.1@8bc32666, **15-patch layer** (001+104+111+113-119+121-125, 119/121 now named, 112 = superseded-by-migration), nix-media file rows, Last updated 2026-10-18; AGENTS/SOPS litellm sidecar added; documentation/INDEX.md refreshed (gitignored — not in commits).
- Added why-comments: mikromcp srcWithLock (registry tarball ships no lockfile), lanzaboote pin rationale, spotify.nix pin-drift pointer, oomd earlyoom hardening.

Judgment calls kept: REPO_OVERVIEW historical DMS gotcha section (labeled, still governs unit ordering), yoga-s2h campaign header (trimmed only rotated-journal caveat + old telemetry), desktop-hyprland After=-ordering narrative (best comment in repo).

**Why:** the repo had ~40 unreaped dated-incident comments; one runbook line could regress the engine patch; docs contradicted code on pins/hibernation.
**How to apply:** audit-line-numbers rot fast — re-read every file before editing (onlyoffice got reworked mid-audit by [[parallel-index-work]]). Re-verify "facts" from audits against eval before baking them into docs (gid 1001→982). Related: [[spotify-spotx-integration-2026-10-18]], [[lucid-perf-round-122-125-2026-10-17]].
