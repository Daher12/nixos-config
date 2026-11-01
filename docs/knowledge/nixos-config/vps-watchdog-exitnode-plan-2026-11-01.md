---
name: vps-watchdog-exitnode-plan-2026-11-01
description: PLAN ONLY (ExitPlanMode DENIED) — new VPS (1c/1GB/15GB) as gatus
  external watchdog + Tailscale exit node, 4th flake host `vps` via
  nixos-infect; all facts verified; NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: session_174c70547700b8658a5f8f6e243c67db
---

User acquired a simple VPS (1 core, 1GB RAM, 15GB NVMe, currently non-NixOS Linux). Plan-mode session 2026-11-01 produced a complete integration plan; **ExitPlanMode was DENIED — NOTHING executed**. User's choices: roles = **external watchdog + Tailscale exit node**; explicitly DECLINED: offsite backups and self-hosted ntfy; reinstall to NixOS accepted (nixos-infect).

**Why (setup assessment):** nix-media is the fleet's single point of failure — all monitoring/alerting/notifications/LiteLLM/autoUpgrade run on it; the daily `ntfy-heartbeat` dead-man's switch has NO automated absence detector (comment in ntfy.nix says the signal is the phone staying quiet). Everything alerts through public ntfy.sh.

**Design (all facts verified in-session):**
- New flake host `vps`: minimal headless, `mkHost { withHardware = false; lix = false; profiles = [ ]; hmModules = [ ]; }`; sshd public key-only (`core.openssh` defaults are fine, mgmtLanCidr=null ⇒ no LAN rule; host module sets openFirewall + PermitRootLogin prohibit-password); zram, GC 7d (15GB disk), autoUpgrade daily `operation = "switch"` with nix-media's git-pull pattern; stateVersion 26.05.
- gatus 5.35 (`services.gatus` in nixpkgs-26.05): 2 active probes (Caddy `https://nix-media.tail6db26.ts.net` [STATUS]==200; LiteLLM `tcp://100.123.189.29:4001` [CONNECTED]==true, 60s, threshold 3) + 1 external push endpoint for the real dead-man detector. Verified OSS syntax: top-level `external-endpoints:` (name/group/token REQUIRED/heartbeat.interval ≥10s/alerts); push API `POST /api/v1/endpoints/{group}_{name}/external?success=true` with `Authorization: Bearer` header; key = lowercased group_name. `heartbeat.interval: 26h`, failure-threshold 1 (default 3 would delay a daily-miss alert by 3 days). `alerting.ntfy` keys: topic (req)/url/priority/default-alert{enabled,failure-threshold,success-threshold,send-on-resolved}. Secrets via `services.gatus.environmentFile` (KEY=value sops file) + Nix-escaped `"\${VAR}"` interpolation. gatus web :8080 tailnet-only (openFirewall=false; tailscale0 trusted).
- nix-media `ntfy-heartbeat` gains one best-effort curl push (guarded `[ -f ]` on secret paths so the sops-stub VM test stays valid).
- Exit node: `modules/features/vpn.nix` needs a new `advertiseExitNode` bool → `services.tailscale.extraSetFlags = [ "--advertise-exit-node" ]` (option exists, doc example is literally that flag; wrapper currently passes nothing through) + routingFeatures "server".
- nixos-infect = **github.com/elitak/nixos-infect** (nix-community URL 404s; gatus.io docs are client-rendered — WebFetch useless, used browser skill). Infect preserves pre-deployed root SSH key; `NIX_CHANNEL=` / `PROVIDER=` env; wipes disk.
- Deploy order matters: infect → pull real hardware-configuration → age key on VPS `/var/lib/sops-nix/key.txt` → create `secrets/hosts/vps.yaml` (dk_password_hash + ntfy_topic copied from nix-media.yaml via /tmp without display, openssl rand tokens) + side file `secrets/hosts/nix-media-gatus.yaml` (nix-media.yaml is on a retired admin key — side-file precedent) → first deploy built ON YOGA `nixos-rebuild switch --flake .#vps --target-host root@<ip>` → tailscale up in background (foreground stalls silently, [[nix-media-tailscale-ssh-access]] lore) → `tailscale set --advertise-exit-node` + admin-console approval → fill gatus_push_url with tailnet IP → nix-media switch.
- CI (ci.yml/bump.yml) enumerate hosts dynamically — no workflow edits; `scripts/test-suite` ALL_HOSTS/DEFAULT_FAST_HOSTS must gain `vps`. VM gate recommendation: only `nix-media-upgrade-pipeline` (ntfy.nix touched).

Residual limitations documented: alerts still ride public ntfy.sh; nobody watches the VPS itself (daily human-silence heartbeat). First on-box autoUpgrade build ~15-30 min on 1 core. Unknowns left as mechanical checks in plan: repo public/private (deploy key branch), provider name, sops keyPath grep.

Plan text was delivered in full via ExitPlanMode content (user has it); follow [[plans-for-weaker-executor]] rules if re-issuing.
