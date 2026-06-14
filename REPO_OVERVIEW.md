# REPO OVERVIEW — Quick Reference for AI Models

This is the single-stop reference for understanding this NixOS configuration repository.

**Last updated:** 2026-06-14 | **NixOS version:** 26.05 "Yarara" | **Flake-based:** Yes

---

## What This Repo Is

A personal NixOS flake managing **3 hosts** (yoga, latitude, nix-media) with a modular architecture. Uses Home Manager, SOPS-nix secrets, Disko disk partitioning, and Btrfs impermanence.

---

## Hosts at a Glance

| Host | Hardware | Role | Special Features |
|------|----------|------|------------------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD Ryzen) | Primary laptop | Impermanence (root wiped), SecureBoot, LUKS, Btrfs, WinApps (Windows VM) |
| **latitude** | Dell E7450 (Intel) | Legacy laptop | Lix package mode, nvidia-disable, TLP power, ext4 |
| **nix-media** | Intel N100 Mini PC | Media server | Docker (Jellyfin, Audiobookshelf), Prometheus+Grafana, Caddy, NFS, systemd-networkd |

---

## Directory Structure — What Goes Where

```
├── flake.nix                  # ENTRY POINT: inputs, outputs, host definitions
├── flake.lock                 # Pinned input revisions
├── lib/
│   └── mkHost.nix             # Host builder function — how all hosts are constructed
├── modules/
│   ├── core/                  # Always-on: boot, nix, users, networking, locale, sysctl
│   ├── features/              # Optional: desktop, bluetooth, fonts, impermanence, VPN, VMs, etc.
│   ├── hardware/              # GPU drivers, KVM, TDP, nvidia-disable
│   └── roles/                 # Server roles (media server NFS)
├── profiles/                  # Role bundles applied via mkHost (laptop, desktop-gnome)
├── hosts/
│   ├── yoga/                  # Host-specific: default.nix, disks.nix (disko), home.nix
│   ├── latitude/              # Host-specific: default.nix, hardware-configuration.nix, home.nix
│   └── nix-media/             # Host-specific: default.nix, docker.nix, monitoring.nix, caddy.nix, etc.
├── home/                      # Shared Home Manager: browsers, terminal, theme, git, winapps
├── pkgs/                      # Custom packages: colloid-gtk, fluent-icons, msty (AppImage)
├── secrets/                   # SOPS-encrypted per-host secrets (age keys)
├── scripts/                   # install.sh (installer), update-safe (safe updater)
├── documentation/             # Troubleshooting, upgrade guides, package docs
└── .github/workflows/         # CI: daily flake updates + lint checks
```

---

## Module Architecture

### Core Modules (`modules/core/`) — Always included

| File | Purpose |
|------|---------|
| `audio.nix` | PipeWire audio, ALSA, PulseAudio, JACK, 48kHz clock |
| `boot.nix` | systemd-boot, Plymouth, tmpfs root, SSD scheduler udev rule |
| `input.nix` | libinput input handling |
| `locale.nix` | Timezone, locale |
| `networking.nix` | Base networking (systemd-resolved, Tailscale, firewall) |
| `nix.nix` | Flakes, caches (nixpkgs cache, cachix), GC, store optimization |
| `shell.nix` | zoxide shell integration |
| `sysctl.nix` | Kernel parameters |
| `systemd.nix` | systemd manager timeouts, coredump disabled |
| `users.nix` | Main user account, group membership |

### Feature Modules (`modules/features/`) — Toggle on/off per host

| File | Purpose |
|------|---------|
| `desktop-gnome.nix` | GNOME 50, GDM, dconf, XDG portals |
| `bluetooth.nix` | BlueZ stack |
| `fonts.nix` | Font packages, fontconfig |
| `impermanence.nix` | Btrfs root wipe on boot, persist to `/persist` |
| `secureboot.nix` | Lanzaboote Secure Boot |
| `sops.nix` | SOPS-nix secret decryption |
| `virtualization.nix` | QEMU/KVM, libvirt |
| `vpn.nix` | Tailscale mesh VPN |
| `power-tlp.nix` | TLP power management |
| `kernel.nix` | Kernel variant (zen) |
| `oomd.nix` | systemd-oomd |
| `zram.nix` | ZRAM swap |
| `nas.nix` | NFS/SMB mounts (Tailscale) |
| `onlyoffice.nix` | OnlyOffice integration |
| `filesystem.nix` | Btrfs scrub/balance, ext4 tuning |
| `network-optimization.nix` | BBR, buffer tuning |

### Hardware Modules (`modules/hardware/`) — Device-specific

| File | Purpose |
|------|---------|
| `amd-gpu.nix` | AMD GPU + VA-API |
| `intel-gpu.nix` | Intel GPU (VPL, OpenCL, GuC) — used by nix-media |
| `amd-kvm.nix` | AMD KVM module |
| `nvidia-disable.nix` | Disable discrete NVIDIA (latitude) |
| `ryzen-tdp.nix` | AMD Ryzen TDP limits |

### Profiles (`profiles/`) — Pre-built role bundles

| File | Includes |
|------|----------|
| `laptop.nix` | bluetooth, TLP, zram, network-optimization, zen kernel, oomd, SecureBoot, Tailscale |
| `desktop-gnome.nix` | GNOME desktop, fonts |

---

## How Hosts Are Built

`lib/mkHost.nix` is the host builder. Every host is defined in `flake.nix` like:

```nix
nixosConfigurations.yoga = mkHost {
  hostname = "yoga";
  mainUser = "dk";
  profiles = [ "laptop" "desktop-gnome" ];
  withHardware = true;
  lix = "source";  # "source" | "package" | false
  hmModules = [ ... ];
  extraModules = [ ... ];
};
```

`mkHost` applies:
1. Core modules (always)
2. Feature modules (always, but toggled via `mkIf`)
3. Hardware modules (if `withHardware = true`)
4. Profile modules
5. Infrastructure: sops-nix, home-manager, disko
6. nixpkgs config with overlays (colloid, fluent)

---

## Home Manager (`home/`)

Shared across all hosts via `home/default.nix`:

| File | Purpose |
|------|---------|
| `default.nix` | Entry point, session vars (`EDITOR=ox`), GNOME extensions |
| `browsers.nix` | Firefox + Brave with forced extensions (uBlock, Bitwarden), policies |
| `terminal.nix` | Ghostty (Nord), Fish shell (hydro, fzf-fish), btop, fastfetch, CLI tools |
| `theme.nix` | Colloid GTK (Nord), Fluent icons, Posy cursors, `switch-theme` script, darkman |
| `git.nix` | Git config (delta, SSH, rebase on pull) |
| `winapps.nix` | Windows RemoteApp via FreeRDP |

Host-specific home additions go in `hosts/<name>/home.nix`.

---

## Secrets (SOPS)

- **Config:** `.sops.yaml` — age key-based, per-host key files
- **Secrets:** `secrets/hosts/{yoga,latitude,nix-media}.yaml`
- **Usage:** Imported via `modules/features/sops.nix`, accessed as `config.sops.secrets.<name>.path`
- **Key:** `age1ff0ly0tej0yk39ycfq0dz0skmvqhe3tzuhdyaq2hkl52enu68sqqrr90s2`

---

## CI/CD (`.github/workflows/bump.yml`)

- **Trigger:** Daily cron (02:00 UTC) + manual dispatch
- **Actions:** Update safe flake inputs → format with `nixfmt` → `nix flake check` → dry-run build all 3 hosts → auto-commit
- **Checks:** `statix`, `deadnix`, `nixfmt` (in `flake.nix`)

---

## Custom Packages (`pkgs/`)

| File | Package | Notes |
|------|---------|-------|
| `colloid-gtk-theme.nix` | Colloid GTK | Git main for GNOME 50 support; nixpkgs version outdated |
| `fluent-icon-theme.nix` | Fluent icons | Git main; nixpkgs version outdated |
| `msty.nix` | Msty Studio | AppImage wrapper (1.8 GB), requires `--no-sandbox` |

---

## Scripts

| File | Purpose |
|------|---------|
| `scripts/install.sh` | Full NixOS installer: disk wipe, Disko, Btrfs snapshot, SSH key restore |
| `scripts/update-safe` | Safe update: pull, update inputs, lint, build, optional deploy |

---

## Key Patterns to Follow

1. **Adding a new host:** Create `hosts/<name>/default.nix` + `home.nix` + `hardware-configuration.nix`, add to `flake.nix` outputs via `mkHost`.

2. **Adding a feature module:** Create `modules/features/<name>.nix`, import it in `modules/features/default.nix`, toggle per-host via `mkIf`.

3. **Adding a custom package:** Create `pkgs/<name>.nix`, call it via `pkgs.callPackage (flakeRoot + "/pkgs/<name>.nix") {}` in the host's `home.nix`.

4. **Secrets:** Add to `secrets/hosts/<host>.yaml` via `sops secrets`, reference in modules via `config.sops.secrets.<name>.path`.

5. **Impermanence:** Add persistent directories to `hosts/<host>/home.nix` under `home.persistence."/persist".directories`.

---

## Common Commands

```bash
# Build and switch
sudo nixos-rebuild switch --flake .#$(hostname)

# Update inputs
nix flake update

# Lint and check
nix fmt && nix flake check

# Safe update (full pipeline)
./scripts/update-safe

# Fresh install
bash scripts/install.sh
```

---

## Documentation

| Document | Topic |
|----------|-------|
| `documentation/INDEX.md` | Categorized documentation index |
| `documentation/impermanence.md` | Btrfs root rollback, @blank template, recovery procedures |
| `documentation/upgrade-26.05.md` | NixOS 25.11 → 26.05 migration |
| `documentation/opencode-provider-persistence.md` | OpenCode provider drops after rebuild |
| `documentation/plymouth_luks_issue.md` | Plymouth + LUKS on AMD |
| `documentation/intel-gpu-metrics.md` | Intel GPU metrics + Grafana |
| `documentation/msty-appimage.md` | Msty Studio AppImage packaging |

---

## File Quick Reference

| Looking for... | Go to... |
|----------------|----------|
| How a host is built | `lib/mkHost.nix` |
| Boot configuration | `modules/core/boot.nix` |
| Desktop environment | `modules/features/desktop-gnome.nix` |
| Theme/dark mode | `home/theme.nix` |
| Terminal/shell | `home/terminal.nix` |
| Browser config | `home/browsers.nix` |
| Disk layout (yoga) | `hosts/yoga/disks.nix` |
| Docker containers | `hosts/nix-media/docker.nix` |
| Monitoring stack | `hosts/nix-media/monitoring.nix` |
| CI pipeline | `.github/workflows/bump.yml` |
| Nix settings/caches | `modules/core/nix.nix` |
| User configuration | `modules/core/users.nix` |
| Tailscale VPN | `modules/features/vpn.nix` |
| Secure Boot | `modules/features/secureboot.nix` |
| SOPS secrets | `modules/features/sops.nix` |
| Custom packages | `pkgs/` |
| Flake definition | `flake.nix` |
