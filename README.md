<div align="center">

```
 _   _ _____  _____  ____         ____ ___  _   _ _____ ___ ____ 
| \ | |_ _\ \/ / _ \/ ___|       / ___/ _ \| \ | |  ___|_ _/ ___|
|  \| || | \  / | | \___ \ _____| |  | | | |  \| | |_   | | |  _ 
| |\  || | /  \ |_| |___) |_____| |__| |_| | |\  |  _|  | | |_| |
|_| \_|___/_/\_\___/|____/       \____\___/|_| \_|_|   |___\____|
```

**A single flake, three machines, zero snowflakes.**

[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Lix](https://img.shields.io/badge/Lix-2.94-7E3FF2?style=for-the-badge)](https://lix.systems)
[![Flakes](https://img.shields.io/badge/Flakes-Enabled-41BAC1?style=for-the-badge)](https://nix.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/Home--Manager-Integrated-5277C3?style=for-the-badge)](https://github.com/nix-community/home-manager)
[![CI](https://img.shields.io/github/actions/workflow/status/daher12/nixos-config/bump.yml?style=for-the-badge&label=CI)](https://github.com/daher12/nixos-config/actions)

[Hosts](#-hosts) · [Architecture](#-how-the-flake-is-organized) · [Operating](#-operating-the-fleet) · [Docs](#-deep-dive-documentation)

</div>

---

## What this is

The complete, declarative configuration for my personal NixOS fleet — a laptop, a
legacy laptop and a headless media server — built from **one flake** and a shared
module library. Nothing is configured by hand on the machines; a fresh install is
`bash scripts/install.sh <host>` away, and every host boots from a
bit-for-bit reproducible closure.

Design principles, visible throughout the repo:

- **Layered modules over copy-paste** — `core` (always on) → `features` (toggled
  per host) → `hardware` (device drivers) → `profiles` (role bundles) → `hosts`
  (per-machine glue). One `mkHost` function assembles all of it.
- **Ephemeral root where possible** — the primary laptop wipes its root
  subvolume on every boot (Btrfs + impermanence); all state is explicitly
  persisted, everything else is disposable.
- **Secrets never in plaintext** — sops-nix with per-host identities, one
  encrypted file per machine.
- **Verified before deployed** — lint checks (`statix`, `deadnix`, `nixfmt`) and
  full dry-builds of all three hosts run on every input bump in CI.

---

## 🖥️ Hosts

| Host | Hardware | Role | Highlights |
|------|----------|------|------------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD Ryzen) | Primary laptop | Hyprland + DMS (`.#yoga`) or GNOME 50 (`.#yoga-gnome`) · Secure Boot (Lanzaboote) · LUKS + Btrfs impermanence · Windows 11 VMs · ZRAM |
| **latitude** | Dell Latitude E7450 (Intel) | Legacy laptop | GNOME · TLP · preload-ng · Disko (LUKS + ext4) · opencode |
| **nix-media** | Intel N100 Mini PC | Headless media server | Jellyfin · Audiobookshelf · Prometheus/Grafana · Caddy · NFS · Docker |

<details>
<summary><strong>📍 yoga — primary laptop (click to expand)</strong></summary>

Daily driver: encrypted, impermanence-wiped, secure-booted work machine.

- **Boot & disk:** Disko-declared GPT → LUKS → Btrfs with split subvolumes
  (`@` root, wiped from the read-only `@blank` template on every boot;
  `@nix` and `@persist` survive). systemd-boot replaced by **Lanzaboote
  Secure Boot**; Plymouth on simpledrm (amdgpu deliberately kept out of the
  initrd — see REPO_OVERVIEW § Known Gotchas).
- **Desktop:** two exclusive builds — Hyprland + DankMaterialShell +
  DankGreeter (`.#yoga`) or GNOME 50 with auto-login (`.#yoga-gnome`);
  switching desktops = rebuilding the other attr, no config edits.
  Colloid-Nord GTK theme, Fluent icons, Posy cursors and darkman
  light/dark switching are shared by both.
- **Power:** custom suspend-then-hibernate sleep hook (`yoga-s2h`) working
  around systemd 260 firmware bugs; TLP; ryzenadj TDP profiles; automatic
  120→60 Hz panel switch on battery (both sessions); hibernation
  currently parked pending an upstream amdgpu/TTM fix (documented in
  REPO_OVERVIEW).
- **Virtualization:** libvirt/QEMU with virt-manager, SPICE USB redirection,
  per-guest launchers with DHCP-reserved IPs (`features.virtualization.guests`
  — currently two Windows 11 guests).
- **Agent tooling:** opencode + ZCode coding agents, MikroTik MCP server
  (optional), LiteLLM gateway module available.

</details>

<details>
<summary><strong>📍 latitude — legacy laptop (click to expand)</strong></summary>

Kept-simple second laptop: GNOME desktop, same home-manager setup as yoga,
Disko-declared ext4 + LUKS without impermanence. Intel-specific tuning (i915
fastboot/FBC), NVIDIA discretely disabled in firmware-level udev rules,
USB-wakeup suppressor service, and `preload-ng` file prefetching.

</details>

<details>
<summary><strong>📍 nix-media — media server (click to expand)</strong></summary>

Headless Intel N100 box serving media to the LAN and over Tailscale.

- **Media stack:** Jellyfin (QSV hardware transcoding via `/dev/dri`,
  Intro Skipper, tmpfs transcode cache) and Audiobookshelf, both in Docker
  with resource limits, health checks and a weekly image-refresh timer;
  `mnamer`-based media renaming tooling (`mnamer-tools` wrapper).
- **Reverse proxy:** Caddy with automatic Tailscale HTTPS, serving a
  self-generating landing page plus `/jellyfin`, `/audiobookshelf`,
  `/grafana` sub-path routes.
- **Monitoring:** Prometheus (node + cAdvisor + Docker + custom Intel GPU
  textfile collector), Grafana with a provisioned dashboard, Alertmanager →
  ntfy push notifications, smartd disk alerts, boot/failure notifications.
- **Storage:** two XFS disks pooled with MergerFS, NFS export to the fleet,
  read-ahead tuning for USB-attached rotational disks.
- **Ops:** nightly auto-upgrade (boot-staged), Sunday idle-aware reboot
  with activity guards, weekly GC and Docker prune.

</details>

---

## ⚙️ How the flake is organized

<details>
<summary><strong>Directory map & layering (click to expand)</strong></summary>

```
nixos-config/
├── flake.nix            # inputs, host definitions, CI checks, dev shell
├── lib/mkHost.nix       # host builder: assembles the module layers
├── modules/
│   ├── core/            # always on: boot, nix, users, networking, ssh, audio…
│   ├── features/        # opt-in per host: desktop, impermanence, VPN, VMs,
│   │                    #   litellm, mnamer, sops, secureboot, tlp, zram…
│   ├── hardware/        # device-specific: AMD/Intel GPU, KVM, ryzen TDP
│   └── roles/           # server roles (media: NFS export)
├── profiles/            # role bundles: laptop, desktop-gnome, desktop-hyprland
├── hosts/               # per-machine config + home-manager glue
├── home/                # shared home-manager: browsers, terminal, theme, git
├── pkgs/                # custom packages: colloid-gtk, fluent-icons,
│   │                    #   zcode (AppImage), mikromcp
├── secrets/             # sops-encrypted per-host secrets
├── tests/               # NixOS VM tests (litellm gateway, SSH firewall)
├── scripts/             # install.sh (fresh install), update-safe (safe updates)
└── .github/workflows/   # weekly input bump + lint CI, opencode PR bot
```

Every host is one `mkHost` call in `flake.nix`:

```nix
yoga = mkHost {
  hostname = "yoga";
  mainUser = "dk";
  withHardware = true;                 # enables modules/hardware + firmware
  lix = true;                          # Lix (default) vs CppNix
  profiles = [ "laptop" "desktop-hyprland" ];  # yoga-gnome attr = desktop-gnome
  extraModules = [ ./hosts/yoga/default.nix ];
  hmModules   = [ ./hosts/yoga/home.nix ];
};
```

`mkHost` then stacks: core + features (always imported, `mkIf`-toggled) +
hardware (optional) + profiles + sops-nix / home-manager / disko wiring +
the shared package overlay. Feature modules expose `features.<name>.enable`
options, so per-host configuration reads as a short, self-documenting block.

</details>

<details>
<summary><strong>🔐 Secrets handling (click to expand)</strong></summary>

sops-nix with **one encrypted file per host** (`secrets/hosts/<host>.yaml`)
and per-host identities:

- **yoga** derives its identity from the persisted SSH host key
  (`method = "ssh"`) — nothing to provision, survives impermanence wipes.
- **latitude / nix-media** use a classic age `key.txt` on the device.
- Every file is also encrypted to the operator key so it can be edited from
  the workstation.
- `dk_password_hash` is load-bearing on every host (declares the login
  password; `mutableUsers = false` everywhere).

Full architecture, re-encryption and rotation procedures: **`SOPS_RUNBOOK.md`**.

</details>

<details>
<summary><strong>🧪 Quality & testing (click to expand)</strong></summary>

- `nix flake check` runs **statix** (idiom), **deadnix** (dead code) and
  **nixfmt** (formatting) over the whole repo, plus evaluation of all three
  hosts.
- **NixOS VM tests** in `tests/` (run explicitly, kept out of CI for speed):
  `nix build .#nixosTests.x86_64-linux.litellm-gateway` and `.#ssh-firewall`.
- **CI** (`.github/workflows/bump.yml`): weekly (Sundays 02:00 UTC) — update
  the safe flake inputs → check → dry-build all three hosts → format →
  auto-commit. Locked inputs (lanzaboote, opencode) only move on explicit
  request.
- `nix develop` provides a secrets/ops toolshell (sops, age, ssh-to-age, yq, jq).

</details>

---

## 🚀 Operating the fleet

```bash
# Rebuild the machine you're on
sudo nixos-rebuild switch --flake .#$(hostname)

# Update inputs the safe way (pull, update safe inputs, check, build, optional deploy)
./scripts/update-safe <host> [build-only|test|boot|switch]   # `nus` on yoga

# Format & lint (nix fmt needs explicit file arguments)
nix fmt <changed .nix files> && nix flake check
```

<details>
<summary><strong>Fresh install on new hardware (click to expand)</strong></summary>

```bash
# Boot the NixOS minimal ISO, connect to the network, then:
sudo su
curl -fsSL https://raw.githubusercontent.com/Daher12/nixos-config/main/scripts/install.sh -o install.sh
bash install.sh <host>        # yoga | latitude | nix-media
```

The installer detects the host's needs by **flake-evaluating the pinned
clone** (Disko devices, impermanence, sops method — never by grepping
source), restores SSH host keys / machine-id / sops identity from an
optional backup USB path, and provisions declarative credentials:
`dk_password_hash` from sops applies at first boot, with the identity
cross-checked against the pinned sops recipients. Post-install
verification checks the bootloader and the sops identity chain.

</details>

---

## 📚 Deep-dive documentation

| Document | Contents |
|----------|----------|
| [`REPO_OVERVIEW.md`](REPO_OVERVIEW.md) | Per-file map of the whole repo, impermanence boot sequence, and **Known Gotchas** (Plymouth/AMD initrd, the suspend-then-hibernate post-mortem, NixOS 26.05 migration notes) |
| [`SOPS_RUNBOOK.md`](SOPS_RUNBOOK.md) | Secrets architecture, re-encryption/rotation procedures, troubleshooting |
| [`AGENTS.md`](AGENTS.md) | Rules for AI coding agents working in this repo (conventions, verification workflow, house rules) |

---

<div align="center">

*NixOS — because reproducibility isn't optional.*

</div>
