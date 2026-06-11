# NixOS Configuration

<div align="center">

[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.93-7E3FF2?style=for-the-badge)](https://lix.systems)
[![Flakes](https://img.shields.io/badge/Flakes-Enabled-41BAC1?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![CI](https://img.shields.io/github/actions/workflow/status/daher12/nixos-config/bump.yml?style=for-the-badge&label=CI)](https://github.com/daher12/nixos-config/actions)

**Personal NixOS flake**

[Hosts](#%EF%B8%8F-hosts) • [Structure](#-structure) • [Quick Start](#-deployment)

</div>

---

## 🖥️ Hosts

| Host | Hardware | Role |
|------|----------|------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD) | Primary laptop with impermanence |
| **latitude** | Dell E7450 (Intel) | Legacy laptop |
| **nix-media** | Intel N100 Mini PC | Media server |

---

## ⚡ Stack

### **Laptops**
- 🎨 GNOME with Nord theming
- 🔒 Secure Boot (Lanzaboote)
- 💾 Btrfs with automated maintenance
- 🌐 Tailscale mesh networking
- 🖥️ QEMU/KVM virtualization

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

## 📁 Structure
```
├── modules/
│   ├── core/        # boot, nix, users, networking
│   ├── hardware/    # GPU drivers, TDP, device quirks
│   ├── features/    # desktop, power, VMs, fonts, filesystems
│   └── roles/       # media server orchestration
├── profiles/        # Role bundles (laptop, desktop)
├── hosts/           # Per-host configuration
├── home/            # Shared home-manager modules
├── secrets/         # SOPS-encrypted credentials
└── scripts/install.sh   # Automated installer
```

---

## 🚀 Deployment

### **Fresh Install**
```bash
# Boot NixOS ISO
sudo su
curl -fsSL https://raw.githubusercontent.com/daher12/nixos-config/main/install.sh -o install.sh
bash install.sh
# Prompts for backup USB (SSH keys, SOPS keys, machine-id)
```

### **Rebuild**
```bash
cd ~/nixos-config
nixos-rebuild switch --flake .#$(hostname)
```

### **Maintenance**
```bash
nix flake update && nix flake check
```

---

<div align="center">

**[Repo Docs](documentation/INDEX.md)** • **[Flakes Guide](https://nixos.wiki/wiki/Flakes)** • **[Issues](https://github.com/daher12/nixos-config/issues)**

</div>
