# NixOS Configuration

<div align="center">

[![NixOS 25.11](https://img.shields.io/badge/NixOS-25.11-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.93-7E3FF2?style=for-the-badge)](https://lix.systems)
[![Flakes](https://img.shields.io/badge/Flakes-Enabled-41BAC1?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)

*Production flake managing workstations and headless infrastructure*

</div>

---

## 🖥️ Hosts

| Host | Hardware | Role |
|------|----------|------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 | Desktop workstation + VMs |
| **latitude** | Dell E7450 | Legacy laptop |
| **nix-media** | Intel N100 Mini PC | Media server + monitoring |

---

## 📁 Structure
```
├── modules/
│   ├── core/        # boot, nix, users, networking
│   ├── hardware/    # GPU drivers, TDP, device quirks
│   └── features/    # desktop, power, VMs, fonts, filesystems
├── profiles/        # Role bundles (laptop, desktop)
├── hosts/           # Per-host configuration
├── home/            # Shared home-manager modules
└── secrets/         # SOPS-encrypted credentials
```

---

## ⚡ Stack

### **Workstations**
- 🎨 GNOME 47 + Wayland with Nord theming
- 🔒 Secure Boot (Lanzaboote)
- 💾 Btrfs with automated maintenance
- 🌐 Tailscale mesh networking

### **Media Server**
- 📺 Jellyfin + Audiobookshelf (Docker)
- 📊 Prometheus + Grafana monitoring
- 🌍 Caddy reverse proxy with Tailscale TLS
- 💿 MergerFS storage pool with NFS exports
- 🔄 Automated updates with idle detection

### **Infrastructure**
- 🔐 SOPS-nix encrypted secrets
- 🤖 GitHub Actions CI (updates, lint, builds)
- 🔧 Systemd-networkd on servers
- 🧩 Modular hardware abstraction

---

## 🚀 Quick Start
```bash
# Clone and build
git clone https://github.com/daher12/nixos-config.git
cd nixos-config
nixos-rebuild switch --flake .#<hostname>

# Maintenance
nix flake update && nix flake check
```

---

## 📋 Requirements

- NixOS **25.11+**
- UEFI firmware
- `sops` CLI for secrets management

---

<div align="center">

**[Documentation](https://nixos.org/manual/nixos/stable/)** • **[Flakes Guide](https://nixos.wiki/wiki/Flakes)** • **[Issues](https://github.com/daher12/nixos-config/issues)**

</div>
