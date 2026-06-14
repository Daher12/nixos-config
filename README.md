<div align="center">

```
 _   _ _____  _____  ____         ____ ___  _   _ _____ ___ ____ 
| \ | |_ _\ \/ / _ \/ ___|       / ___/ _ \| \ | |  ___|_ _/ ___|
|  \| || | \  / | | \___ \ _____| |  | | | |  \| | |_   | | |  _ 
| |\  || | /  \ |_| |___) |_____| |__| |_| | |\  |  _|  | | |_| |
|_| \_|___/_/\_\___/|____/       \____\___/|_| \_|_|   |___\____|
```

**Declarative. Reproducible. Sustainable.**

[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.93-7E3FF2?style=for-the-badge)](https://lix.systems)
[![Flakes](https://img.shields.io/badge/Flakes-Enabled-41BAC1?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/Home--Manager-Integrated-5277C3?style=for-the-badge)](https://github.com/nix-community/home-manager)
[![CI](https://img.shields.io/github/actions/workflow/status/daher12/nixos-config/bump.yml?style=for-the-badge&label=CI)](https://github.com/daher12/nixos-config/actions)

[Hosts](#-hosts) · [Features](#-features) · [Structure](#-structure) · [Deploy](#-deploy)

</div>

---

## 🖥️ Hosts

| Host | Hardware | Role |
|------|----------|------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD) | Primary laptop |
| **latitude** | Dell E7450 (Intel) | Legacy laptop |
| **nix-media** | Intel N100 Mini PC | Media server |

---

## ⚡ Features

<details open>
<summary><strong>🐧 Desktop (Laptops)</strong></summary>

| Category | What's Inside |
|----------|---------------|
| **Desktop** | GNOME + Nord theming, Colloid GTK, Fluent icons |
| **Security** | Secure Boot via Lanzaboote, SOPS-nix encrypted secrets |
| **Storage** | Btrfs with automated maintenance, ZRAM |
| **Networking** | Tailscale mesh, systemd-networkd optimization |
| **Virtualization** | QEMU/KVM with AMD GPU passthrough |
| **Power** | TLP, Ryzen TDP control, oomd |

</details>

<details open>
<summary><strong>📡 Media Server</strong></summary>

| Category | What's Inside |
|----------|---------------|
| **Services** | Jellyfin, Audiobookshelf, mnamer, ntfy |
| **Reverse Proxy** | Caddy with Tailscale TLS |
| **Monitoring** | Prometheus + Grafana |
| **Storage** | MergerFS pool, NFS exports, automated maintenance |
| **Automation** | Idle-aware updates, Docker orchestration |

</details>

<details open>
<summary><strong>🏗️ Infrastructure</strong></summary>

| Category | What's Inside |
|----------|---------------|
| **Secrets** | SOPS-nix with age keys |
| **CI/CD** | GitHub Actions — lint (`statix`, `deadnix`, `nixfmt`), build checks, flake updates |
| **Disk** | Disko declarative partitioning, impermanence (root tmpfs) |
| **Nix** | Lix package manager, Flakes, modular `mkHost` abstraction |

</details>

---

## 📁 Structure

```
nixos-config/
├── modules/          core · hardware · features · roles
├── profiles/         role bundles (laptop, desktop)
├── hosts/            per-machine config & overrides
├── home/             shared home-manager modules
├── lib/              custom nix helpers (mkHost)
├── pkgs/             custom package definitions
├── secrets/          sops-encrypted credentials
└── scripts/          installer & update helpers
```

---

## 🚀 Deploy

### Fresh Install

```bash
# 1. Boot the NixOS minimal ISO and connect to the internet
sudo su

# 2. Pull and run the installer for your host (yoga, latitude, nix-media)
curl -fsSL https://raw.githubusercontent.com/daher12/nixos-config/main/scripts/install.sh -o install.sh
bash install.sh <host>
```

### Rebuild

```bash
cd ~/nixos-config
nixos-rebuild switch --flake .#$(hostname)
```

### Update Flake Inputs

```bash
nix flake update
nix flake check
```

### Lint & Format

```bash
nix fmt                          # format all .nix files
nix flake check                  # runs statix, deadnix, nixfmt checks
```

---

<div align="center">

*NixOS — because reproducibility isn't optional.*

</div>
