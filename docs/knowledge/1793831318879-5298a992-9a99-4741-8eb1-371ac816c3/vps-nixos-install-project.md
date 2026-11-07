---
name: vps-nixos-install-project
description: Ongoing project — convert cheap Virtualizor VPS (107.150.20.39) to
  NixOS; write-burst disk freezes killed past attempts; throttled pre-seed plan
metadata:
  node_type: memory
  type: project
  originSessionId: session_833e2d2b4301d87299e306169faabd1f
---

Goal: install NixOS on the user's cheap VPS (provider vpsportal.com, Virtualizor panel; VPS id 46281; hostname vps140190-koz) and finish the staged `vps` host work in the repo at `/home/dk/nixos-config` (this machine, yoga, is the build box: Lix 2.95.4, 811G free in /nix).

VPS facts: 107.150.20.39, 1 vCPU / 955MB RAM / 15GB ext4 root on **/dev/vda2**, BIOS boot, /tmp is a 478MB tmpfs. SSH root@ with yoga's key works (re-confirmed 2026-11-04).

Hard-won constraints (as of 2026-11-04):
- **Sustained multi-GB write bursts (nix build/unpack ~1.5–2GB) froze VPS storage twice** (jbd2 hung_task, no ssh banner); small/throttled writes are fine. Never build, unpack, or unthrottled-copy on the box; `rm -rf /nix` in one shot is also risky (suspected attempt-2 trigger).
- Virtualizor panel API and `act=mcp` MCP endpoint are dead provider-side ("MCP server has been disabled by the administrator"); a new API key pair (YKZ…) was given 2026-11-04 to retest once. Panel actions (power-cycle, reinstall, VNC) are user-browser-only.
- nixos-infect has no pre-seed/flake support — only its post-build tail is reusable.

Approved plan (2026-11-04): build both closures on yoga (temp `vps-install` minimal attr + real `.#vps`; two-stage needed because sops secrets can't decrypt until host key exists on a booted NixOS); seed VPS store via chunked `nix-store --export` streamed at 3MB/s (`pv -L`) into `nix-store --import` over ssh; abort on hung_task/stall; cutover by replicating infect's tail with `NIXOS_INSTALL_BOOTLOADER=1 switch-to-configuration boot`; then sops host_vps key + `.sops.yaml` rules, stage-B delta seed, docs, `test-suite fast` + `nix-media-upgrade-pipeline` VM battery, commits, batch-wise Ubuntu-leftover cleanup. Repo gaps to fix: fake `/dev/vda1` in hosts/vps/hardware-configuration.nix, no `host_vps` rules in `.sops.yaml`, staged work uncommitted on `main`.

Panel API credentials were pasted in chat (never into the repo); user should rotate them after.
