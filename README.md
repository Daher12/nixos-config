# Unified NixOS Configuration

This repository contains a modular NixOS flake configuration targeting **NixOS 25.11**. It utilizes a unified architecture to manage multiple hosts with shared profiles, hardware-specific modules, and a consistent Home Manager environment.

## 🏗️ Configuration Overview

* **Package Manager**: Transitioned to **Lix** (v2.93.3-2) for enhanced performance and modern Nix features.
* **System Architecture**: Uses a `mkHost` abstraction to inject global `inputs`, shared `overlays`, and consistent `specialArgs` across all configurations.
* **Module System**:
* **Core**: Mandatory system services including Secure Boot (Lanzaboote), custom user management, and low-latency Pipewire audio.
* **Hardware**: Specialized modules for AMD/Intel GPUs and NVIDIA disabling.
* **Features**: Optional toggles for virtualization, TLP power management, zram, and filesystem-specific optimizations.


* **Home Manager**: Fully integrated as a NixOS module with shared package sets and global configuration for the user `dk`.

---

## 💻 Host Descriptions

### 1. `yoga` (Lenovo Yoga 7 Slim Gen 8)

* **Role**: Primary high-performance workstation.
* **Kernel**: Zen variant with AMD-specific optimizations (`amd_pstate=active`) and `ryzen-smu` for power monitoring.
* **Graphics**: AMD GPU enabled with Vulkan and VA-API support.
* **Storage**: Btrfs on root/home/nix with `zstd:1` compression, `discard=async`, and automated monthly scrub/balance maintenance.
* **Performance**: 100% zram allocation, `earlyoom` (5% threshold), and `ryzen-tdp` for custom AC/Battery power profiles.
* **Security**: Secure Boot enabled via Lanzaboote with `sbctl` integration.

### 2. `e7450-nixos` (Dell Latitude E7450)

* **Role**: Portable legacy laptop.
* **Kernel**: Zen variant with specific Intel i915 parameters for fastboot and FBC.
* **Graphics**: Intel GPU enabled; dedicated NVIDIA hardware explicitly disabled to save power.
* **Storage**: Standard Ext4 filesystem with high-performance mount options (`noatime`, `commit=30`).
* **Performance**: Preload-NG enabled for faster application launching and System76-scheduler for foreground process boosting.
* **Power**: TLP optimized for battery life and custom systemd services to disable spurious USB wakeups.

---

## 🚀 Key Commands

* **Build/Switch (Yoga)**:
```bash
sudo nixos-rebuild switch --flake .#yoga

```


* **Build/Switch (Latitude)**:
```bash
sudo nixos-rebuild switch --flake .#e7450-nixos

```


* **Format Code**:
```bash
nix fmt

```
