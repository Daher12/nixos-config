# REPO OVERVIEW — Quick Reference for AI Models

This is the single-stop reference for understanding this NixOS configuration repository.

**Last updated:** 2026-06-27 | **NixOS version:** 26.05 "Yarara" | **Flake-based:** Yes

---

## What This Repo Is

A personal NixOS flake managing **3 hosts** (yoga, latitude, nix-media) with a modular architecture. Uses Home Manager, SOPS-nix secrets, Disko disk partitioning, and Btrfs impermanence.

---

## Hosts at a Glance

| Host | Hardware | Role | Special Features |
|------|----------|------|------------------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD Ryzen) | Primary laptop | Impermanence (root wiped), SecureBoot, LUKS, Btrfs, WinPodX (Windows VM) |
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
| `virtualization.nix` | QEMU/KVM, libvirt (fallback — WinPodX is primary) |
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
| `winpodx.nix` | WinPodX — seamless Windows apps via FreeRDP RemoteApp |

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
| `scripts/install.sh` | Host-agnostic NixOS installer: Disko, Btrfs snapshot, SSH key restore |
| `scripts/update-safe` | Safe update pipeline: pull, update inputs, lint, build, optional deploy |

### `install.sh` — Host-Agnostic Installer

```bash
bash scripts/install.sh <host>    # host is required: yoga, latitude, nix-media
```

The script auto-detects host features from the config:
- **Disko**: checks for `hosts/<host>/disks.nix` → runs Disko if present
- **Impermanence**: greps host config for `impermanence.enable = true` → creates `@blank` snapshot
- **Persist paths**: detects `/persist` references → uses `/mnt/persist/system` or `/mnt` accordingly

Flow: clone → detect features → (optional Disko) → password hash → (optional @blank snapshot) → state restoration → `nixos-install`

### `update-safe` — Safe Update Pipeline

```bash
./scripts/update-safe <host> [build-only|test|boot|switch]
```

Steps:
1. `git pull --ff-only` — fast-forward only, no merge
2. `nix flake update` — updates nixpkgs, nixos-hardware, home-manager, sops-nix, disko, impermanence, winapps, preload-ng
3. `nix flake check --impure --keep-going` — runs statix, deadnix, nixfmt checks
4. `nix build` — builds the host's toplevel derivation
5. Optionally activates: `test` (temporary), `boot` (next boot), `switch` (live)

Safe inputs are updated; locked inputs (lanzaboote, lix, lix-module) are NOT updated to avoid surprise breakage.

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
./scripts/update-safe yoga switch

# WinPodX first-time setup (after switch)
winpodx setup
winpodx app run desktop

# Fresh install
bash scripts/install.sh yoga
```

---

## Impermanence — How It Works (yoga only)

The root filesystem uses **split Btrfs subvolumes**:

```
Btrfs top-level (subvolid=5)
├── @           → mounted at /      — wiped on every boot
├── @blank      → template snapshot — read-only, never mounted
├── @nix        → mounted at /nix   — persistent
└── @persist    → mounted at /persist — persistent
```

**Boot sequence:**
1. `@blank` validated (exists, read-only, has required mount-point dirs)
2. `@` recursively deleted
3. Fresh read-write snapshot created from `@blank` → `@`
4. Persistent subvolumes (`/nix`, `/persist`) mounted on top
5. Impermanence module bind-mounts persist entries to their target paths under `/`

All persistent data lives on `/persist`. The `@` subvolume contains only the NixOS skeleton (symlinks into `/nix/store`, mount-point dirs, `/etc` files from `environment.persistence`).

**Required `@blank` directories:** `nix persist boot home etc tmp var var/log var/lib var/lib/sops-nix var/lib/sbctl`

**Two persistence scopes:**
- `/persist/system` — system state: service data (`/var/lib/*`), SSH keys, NetworkManager, machine-id
- `/persist` — user home dirs: desktop folders, config repos

**Adding a new Btrfs subvolume under `/`:** Add the mount-point dir to the validation list in `modules/features/impermanence.nix`, then update `@blank`:
```sh
sudo mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
sudo btrfs subvolume snapshot -r /mnt/@ /mnt/@blank-tmp
sudo btrfs subvolume delete /mnt/@blank
sudo mv /mnt/@blank-tmp /mnt/@blank
sudo umount /mnt
```

**Initrd constraint:** The rollback script runs in the systemd initrd. Only `btrfs`, `mount`, `umount`, `chmod` are available — no `grep`, `awk`, `sed`, `find`, `ls`. Use bash builtins for control flow.

---

## Known Gotchas

### Plymouth + AMD GPU (yoga)

`amdgpu` loaded in initrd unregisters `simpledrm` before Plymouth can attach. This causes the LUKS prompt to fall back to text mode with an 8s delay.

**Root cause:** `amdgpu` probes the GPU → calls `drm_aperture_remove_conflicting_framebuffers()` → simpledrm device torn down → Plymouth's `use-simpledrm` predicate finds no device → 8s timeout → text-mode fallback.

**Why cold boot works, reboot fails:** Cold boot loads amdgpu firmware from disk (~3-5s), simpledrm survives long enough. Reboot loads from CPU/RAM caches (<1s), simpledrm is gone before Plymouth starts.

**Current state:** `amdgpu` is blacklisted in initrd via `initcall_blacklist=amdgpu_init` in `hosts/yoga/default.nix`. Plymouth attaches to simpledrm deterministically. amdgpu loads normally after switch-root.

**Verification:**
```sh
# amdgpu must NOT be in initrd
sudo lsinitrd /nix/store/*-initrd-linux-*/initrd 2>/dev/null | grep amdgpu
# Should be empty

# Plymouth should attach to simpledrm
journalctl -b -o cat | grep -E "simple-framebuffer.*Registered|plymouth.*Attached"
# Should show simpledrm registering before Plymouth attaches
```

### NixOS 26.05 Breaking Changes

| Change | File | Fix |
|--------|------|-----|
| `services.resolved.extraConfig` removed | `modules/core/networking.nix` | Migrate to `services.resolved.settings` attrset |
| `gdm.wayland` removed (Wayland mandatory) | `modules/features/desktop-gnome.nix` | Delete `wayland = true` line |
| `programs.adb` removed | `modules/core/users.nix` | Use `pkgs.android-tools` in systemPackages |
| Grafana `secret_key` required | `hosts/nix-media/monitoring.nix` | Set `secret_key = "SW2YcwTIb9zpOOhoPsMm"` |
| `fastfetchMinimal` renamed | `hosts/nix-media/default.nix`, `home/terminal.nix` | Change to `fastfetch.minimal` |
| `nixfmt-rfc-style` renamed | `flake.nix` | Change to `nixfmt` |
| WinApps removed | `flake.nix`, `home/`, `hosts/yoga/` | Replaced by WinPodX — see `documentation/winpodx.md` |
| opencode `libstdc++.so.6` missing | `home/terminal.nix` | Wrap binary with `LD_LIBRARY_PATH` pointing to `stdenv.cc.cc.lib` |
| Docker 28 marked insecure | `hosts/nix-media/docker.nix` | Pin `package = pkgs.docker_29` |

**First switch after upgrade requires reboot** — dbus-broker replaces dbus-daemon, needs full restart.

### Intel GPU Metrics (nix-media)

`intel-gpu-tools` 2.2→2.3 changed output format. The awk parser in `hosts/nix-media/monitoring.nix` was updated to handle the new format. If metrics break after an update, check the parser.

---

## Recovery Procedures

### Boot fails — "missing template snapshot"

`@blank` deleted or corrupted. From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs subvolume show /mnt/@          # check if @ still exists
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank  # recreate from @
umount /mnt
exit
```

### Boot fails — "not a read-only snapshot"

`@blank` exists but lost its read-only flag. From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs property set -ts /mnt/@blank ro true
umount /mnt
exit
```

### Boot fails — "missing required path"

A directory is missing from `@blank` (partition layout changed without template update). From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs subvolume delete /mnt/@blank
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank
umount /mnt
exit
```

### General rule

Any error in the rollback script aborts the service → `OnFailure = "emergency.target"` → initrd emergency shell. `@` is never touched unless `@blank` passes all validations, so data is preserved.

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
| Windows apps (WinPodX) | `home/winpodx.nix` |
| Disk layout (yoga) | `hosts/yoga/disks.nix` |
| Docker containers | `hosts/nix-media/docker.nix` |
| Monitoring stack | `hosts/nix-media/monitoring.nix` |
| CI pipeline | `.github/workflows/bump.yml` |
| Nix settings/caches | `modules/core/nix.nix` |
| User configuration | `modules/core/users.nix` |
| Tailscale VPN | `modules/features/vpn.nix` |
| Secure Boot | `modules/features/secureboot.nix` |
| SOPS secrets | `modules/features/sops.nix` |
| Impermanence module | `modules/features/impermanence.nix` |
| Custom packages | `pkgs/` |
| Flake definition | `flake.nix` |
