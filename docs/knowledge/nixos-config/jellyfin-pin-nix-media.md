---
name: jellyfin-pin-nix-media
description: RESOLVED 2026-09-19 — pin DROPPED (user choice); :latest + weekly auto-update accepted; 12.1.0 running (supervised); surprise 12.0 upgrade root-caused (power-off + Persistent timer catch-up); health-cmd + DOCKER_MODS fixes staged, rebuild pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c869e9b6-66a9-4d86-9a51-3c823ad5be8b
---

Final state (2026-09-19 late evening): user decided **"drop the pin entirely"** — `images.jellyfin = :latest`, weekly `docker-image-refresh.timer` (Sun 03:00, Persistent=true) auto-updates accepted. Live container upgraded to **12.1.0** under supervision 20:57 (clean: plugin loads, zero ERRs, health + caddy 200).

**Root cause of the "surprise" 12.0 upgrade** (proven from journald, replaces the earlier "user's manual upgrade" guess): host powered off 2026-08-30→09-11; `:latest` moved to 12.0 (pushed 09-08) during that window; at boot 09-11 23:52 the unit found NO local image (Monday `docker-prune --all` had removed it while the container wasn't running) → fresh `docker pull :latest` = 12.0 → DB schema migrated on first boot; 12s later the Persistent timer fired catch-up (missed 2 Sundays) and restarted everything. The manual upgrade process from the 12.0 announcement was never followed; no pre-upgrade backup exists. 12.0 (rel. 09-07) = the major/breaking release; 12.1 (rel. 09-14) = routine bugfix (~47 fixes; X bump = major, Y = bugfix-only per versioning policy — watch for 13.x).

Stable facts:
- 10.x downgrade is NOT viable: tried 10.11.11 2026-09-19 → `no such column` errors, logins/Continue-Watching broke (~7h degraded, corrected same evening). Lesson: determine the previously-running version from `journalctl CONTAINER_NAME=jellyfin`, never from registry tag dates.
- Host access: no sudo on nix-media (docker-group only); container recreated via manual `docker run` (restart=unless-stopped; unit converges at next rebuild).
- Server serves at `/` (BaseUrl env not applied on any version); Caddy `strip_prefix /jellyfin` is the working combo — health-cmd fixed to probe `/health` (badge truthful now).
- DOCKER_MODS removed from docker.nix: ghcr returns 403 DENIED since ~2026-09-12 (project dropped the docker-mod; new install path = version-aware plugin repo manifest https://intro-skipper.org/manifest.json). Plugin persists in /config/data/plugins (Intro Skipper 12.0.4.0, loads on 12.1; ffmpeg 8.1.2 ≥ 7.1.3 requirement). Plugin updates: check Dashboard → Plugins → Repositories.
- Backups: `~/docker/jellyfin-db-backup-20260919.tar.gz` (209M) + one stale auto-zip 2026-02-02 — enable scheduled backups before the next major lands via the timer.
- The "Sammlungen und Playlisten" task error was purely the 10.11.11 schema symptom — zero occurrences on 12.x.

**Still pending (user): rebuild `.#nix-media`** — deployed gen predates the staged docker.nix fixes; until then the next timer restart recreates the container with OLD unit flags (dead DOCKER_MODS error + `/jellyfin/health` unhealthy badge return — cosmetic only, version stays 12.1).

Related: [[parallel-index-work]] (QC validated combined index incl. other session's firmware-pin removal), [[ask-dont-infer-system-state]] (cause proven from journald, not assumed), [[user-communication-style]].
