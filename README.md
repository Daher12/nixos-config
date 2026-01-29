```markdown
# NixOS Configuration

[![NixOS 25.11](https://img.shields.io/badge/NixOS-25.11-blue.svg)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.93-blueviolet.svg)](https://lix.systems)

Production flake managing workstations and headless infrastructure with encrypted secrets and automated maintenance.

## Hosts

```
yoga        Lenovo Yoga 7 Slim (Ryzen)  →  Desktop workstation + VMs
latitude    Dell E7450 (Intel)          →  Legacy laptop
nix-media   N100 Mini PC                →  Media server + monitoring
```

## Structure

```
modules/
├── core/       boot, nix, users, networking
├── hardware/   GPU drivers, TDP, device quirks
└── features/   desktop, power, VMs, fonts, filesystems

profiles/       Role bundles (laptop, desktop)
hosts/          Per-host configuration
home/           Shared home-manager modules
secrets/        SOPS-encrypted credentials
```

## Stack

**Workstations**
- GNOME with Nord theming
- Secure Boot (Lanzaboote)
- Btrfs with automated maintenance
- Tailscale mesh networking

**Media Server**
- Jellyfin + Audiobookshelf (Docker)
- Prometheus + Grafana monitoring
- Caddy reverse proxy with Tailscale TLS
- MergerFS storage pool with NFS exports
- Automated updates with idle detection

**Infrastructure**
- SOPS-nix encrypted secrets
- GitHub Actions CI (flake updates, lint, dry-run builds)
- Systemd-networkd on servers
- Modular hardware abstraction

## Quick Start

```bash
git clone https://github.com/daher12/nixos-config.git
cd nixos-config
nixos-rebuild switch --flake .#<hostname>

# Maintenance
nix flake update && nix flake check
```

## Requirements

- NixOS 25.11+
- UEFI firmware
- `sops` CLI for secrets management
```
