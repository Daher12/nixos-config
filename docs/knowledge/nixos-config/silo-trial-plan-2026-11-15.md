---
name: silo-trial-plan-2026-11-15
description: PLAN ONLY (ExitPlanMode DENIED) — Silo media server A/B trial
  alongside Jellyfin on nix-media; full design + Silo deployment facts in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_dd550c95-541d-43df-aa85-ffface0af68c
---

2026-11-15 plan-mode session: user asked how cleanly Silo (siloserver.org, AGPL Go media server) could run alongside Jellyfin on nix-media for an A/B decision. Full plan built, ExitPlanMode DENIED — NOTHING executed.

**Verdict: very clean.** Silo's official deploy = single omnibus Docker image `ghcr.io/silo-server/silo-server:latest` (bundles Silo + PostgreSQL 18 + Redis); not in nixpkgs. nix-media already runs jellyfin/audiobookshelf/cadvisor as oci-containers in hosts/nix-media/docker.nix — everything additive.

## Silo facts (verified from docs + upstream compose)
- Container ports FIXED: 8080 web (host-mappable), 8096 Jellyfin-compat, 13378 ABS-compat → both COLLIDE with live services; trial publishes ONLY web port 8090→8080.
- **No sub-path proxying** (docs: "use a dedicated hostname at its root") → cannot reuse the /jellyfin/* caddy handle pattern. Plan: second caddy vhost `nix-media.tail6db26.ts.net:8443` reusing `get_certificate tailscale` (same hostname = shared cert, no Tailscale admin changes). HTTPS is REQUIRED for Silo mobile/TV apps (sign-in always via HTTPS address); apps auto-switch to LAN address at home.
- SECRET_KEY env (openssl rand -base64 48) encrypts db; lost = forced empty-db restart → new sops side file `secrets/hosts/nix-media-silo.yaml` (nix-media.yaml still on retired admin key — side-file rule), value format `SECRET_KEY=<key>` because it's consumed via oci-containers `environmentFiles`.
- PUID/PGID must read media, may NOT be 999/998/997 → use 1001/982 (nfsAnon ids, same as jellyfin). Volumes: /config, transcode, download-artifacts, catalog-seeds:ro (upstream compose mounts it), media :ro at /mnt/media/*. Optional /dev/dri for QSV. Omitted deliberately: NET_ADMIN cap (BBR only, droppable), /proc host mounts (LXC-only), Meilisearch.
- Built-in watch-history import from Jellyfin/Plex/Emby; readiness probe `GET /api/v1/ready`.

## Planned wiring (files, all additive)
roles/media.nix ports += silo=8090, siloHttps=8443 · docker.nix silo container (mirrors jellyfin: /dev/dri + group-add render/video, --cpus=2.0, --shm-size=2g, --stop-timeout=120, tmpfs 4G /var/cache/silo for transcode parity) + refresh-script line + tmpfiles · default.nix sops secret + tailscale0 port · caddy.nix split proxiedServices vs rootServices (landing card only) + :8443 vhost · ntfy criticalServices · monitoring DockerUnitFailed regex · tests/nix-media-pipeline.nix stub list + image assertion · .sops.yaml rule widened `nix-media(-[a-z0-9-]+)?\.yaml$` · REPO_OVERVIEW/README.

Removal if Jellyfin wins: autoStart=false, docker rm, rm -rf /home/dk/docker/silo /var/cache/silo. If Silo wins: drop jellyfin, republish silo 8096→8096 for Jellyfin clients.

**Why:** the user's goal is a decision between the two servers, with zero risk to the live library (media ro on both sides).
**How to apply:** if the user reopens this, the plan above is self-contained; the USER must create the SECRET_KEY themselves (see [[no-secrets-in-chat]]) before any dry-build (sopsFile must exist in git index).
