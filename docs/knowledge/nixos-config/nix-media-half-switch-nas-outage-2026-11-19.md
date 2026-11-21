---
name: nix-media-half-switch-nas-outage-2026-11-19
description: "NAS spinner on yoga = symptom of nix-media half-applied switch:
  restart wave stopped whole service fleet 2026-11-19 00:41:54, start phase
  never ran; reboot recovery + yoga nas.nix fail-fast hardening"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_76d092f2-567f-4fda-a2d3-db7a1ccb4ea5
---

**Symptom:** "NAS not available through nautilus" on yoga (2026-11-19 ~12:25). Nautilus exonerated immediately — `ls /mnt/nas` hung too. The "NAS" sidebar bookmark is `file:///mnt/nas` (hosts/yoga/home.nix), an NFSv4.2-over-Tailscale automount from nix-media (features.nas). No SMB anywhere in the fleet (no samba/avahi/wsdd; gvfsd backends present but unused); REPO_OVERVIEW.md row was stale, fixed.

**Root cause (user-attributed):** the user's own `nixos-rebuild switch` on nix-media over Tailscale SSH at 00:41:53 Nov 19 (sessions opened 20:17 + 23:37). Its restart wave (nixpkgs f684076 unit changes) stopped the ENTIRE fleet at 00:41:54 — docker-jellyfin/audiobookshelf/silo, caddy, grafana, prometheus, alertmanager, litellm, rpcbind, nfs-server — then the SSH sessions closed 00:42:06 **before the switch's start phase ran**. Result: half-applied switch, totally silent — `is-system-running`=running, 0 failed units, 0 pending jobs, only 36 active services. This morning's 05:12 `nixos-upgrade` runs in **boot mode** (`action = boot` in journal) so it only staged a generation and didn't rescue.

**Recovery:** user chose reboot (ran `ssh nix-media sudo reboot` 13:07); booted gen = `wbwm49fa` = exactly what 05:12 nixos-upgrade staged. **Post-reboot NO switch/boot needed** — a fresh boot fully converges services with config, which is the point of boot-mode after a half-switch. Verified: all services active, 2049 listening, yoga mount OK (still old timeo=600 until next yoga switch). Reboot timing note: sshd answered ~10s before services were up — verify probes need a settle delay.

**Why:** a switch interrupted between stop and start phase leaves zero failure evidence — only symptom is services that are `enabled` yet inactive.

**How to apply:** after any interrupted/failed switch, check `systemctl list-units --state=inactive` against expectations (or count active services), not just `--failed`. Diagnostics that pinned it: port 2049 **connection refused** (not timeout) = nfsd down but host reachable; `/run/current-system` mtime ≈ incident time = which switch; `journalctl -u <svc>` showing Stopping-without-Starting = half-switch signature. Agent can't fix: sudo on nix-media needs a password (no NOPASSWD over Tailscale SSH); [[nix-media-tailscale-ssh-access]] (background ssh reconfirmed).

**Repo changes (EXECUTED, fast green, staged):** `modules/features/nas.nix` timeo=600→150 + `x-systemd.mount-timeout=30s` — unreachable NAS now errors ~30s instead of multi-minute hang; comment documents incident. Pending yoga switch.
