# Unified NixOS Configuration

[![NixOS](https://img.shields.io/badge/NixOS-25.11-blue.svg)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.93.3-blueviolet.svg)](https://lix.systems)
[![Flake](https://img.shields.io/badge/Flake-enabled-green.svg)](https://nixos.wiki/wiki/Flakes)

Production-grade NixOS flake managing 3 hosts (2 workstations, 1 headless media server) with modular architecture, automated maintenance, and encrypted secrets.

## Architecture

**Hosts:**
- `yoga` (Lenovo Yoga 7 Slim Gen 8): AMD workstation with 
- `latitude` (Dell E7450): Legacy laptop optimized 
- `nix-media` (Intel N100 Mini PC): Headless media server with Docker containers, storage pool, monitoring stack

**Core Design:**
- **Modularity**: Composable `core/`, `hardware/`, `features/` modules with profile-based bundling (`laptop`, `desktop-gnome`)
- **Secrets**: SOPS-nix with per-host age keys (SSH-derived or dedicated)
- **Unified Overlays**: Shared unstable overlay, consistent palette theming (Nord)
- **CI/CD**: Daily automated flake updates with dry-run verification, weekly auto-upgrade on `nix-media`

## Quick Start
```bash
# Clone and build
git clone https://github.com/daher12/nixos-config.git
cd nixos-config
nixos-rebuild switch --flake .#<hostname>

# Maintenance
nix flake update                    # Update all inputs
nix flake check                     # Lint (statix/deadnix/nixfmt)
```

## Key Features

**Security & Secrets:**
- Lanzaboote Secure Boot (yoga, latitude)
- SOPS-nix encrypted WiFi credentials, Grafana passwords, ntfy topics
- Tailscale mesh networking with WireGuard

**Performance Optimizations:**
- Ryzen TDP control with AC/battery profiles (yoga: 54W/18W)
- Btrfs with zstd compression, async discard, automated scrub/balance
- ZRAM with tuned kernel parameters (`vm.swappiness=100`)
- BBR congestion control, fq qdisc, TCP Fast Open

**Desktop (GNOME 47 + Wayland):**
- Nord-themed GTK/Qt with automatic light/dark switching (darkman)
- Ghostty terminal, Fish shell with hydro prompt
- GPU-accelerated kmscon console

**Media Server Stack:**
- Jellyfin + Audiobookshelf in Docker with Intel QSV transcoding
- Prometheus + Grafana monitoring with custom Intel GPU metrics
- Caddy reverse proxy with Tailscale TLS certificates
- MergerFS pooled XFS storage, NFS exports over Tailscale
- Weekly automated upgrades with activity-aware reboot logic

## Structure
```
.
├── flake.nix              # Entry point, host definitions
├── lib/
│   ├── mkHost.nix         # Host builder with shared args
│   └── palette.nix        # Nord color scheme
├── modules/
│   ├── core/              # Base system (boot, nix, users, networking)
│   ├── hardware/          # GPU drivers, TDP control, NVIDIA disable
│   └── features/          # Optional toggles (desktop, power, VMs, fonts)
├── profiles/
│   ├── laptop.nix         # Battery optimizations, SOPS WiFi, Tailscale
│   └── desktop-gnome.nix  # GNOME with curated exclusions
├── hosts/
│   ├── yoga/              # Btrfs, Secure Boot, Windows 11 VM, WinApps
│   ├── latitude/          # Ext4, preload-ng, Intel GPU tuning
│   └── nix-media/         # systemd-networkd, Docker, monitoring, ntfy
├── home/                  # Shared Home Manager (browsers, git, terminal, theme)
└── secrets/
    └── hosts/             # SOPS-encrypted per-host YAML files
```

## Highlights

- **Zero-touch WiFi**: Encrypted PSKs via SOPS templates, drift detection with `restartTriggers`
- **Fail-safe upgrades**: `nix-media` stages updates daily, reboots weekly only when idle (Jellyfin session check)
- **Resource efficiency**: systemd slicing, cgroup limits, priority tuning (Jellyfin gets 8x IOWeight vs cAdvisor)
- **Observability**: Prometheus alerts via ntfy push notifications, SMART disk monitoring, systemd failure hooks
- **Reproducibility**: Pinned registry, locked inputs, `flake.lock` auto-updated via GitHub Actions

## Requirements

- NixOS 25.11+
- UEFI system (Secure Boot optional but recommended)
- For secrets: `sops` CLI, age keys in `.sops.yaml`
