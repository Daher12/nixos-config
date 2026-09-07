# REPO OVERVIEW — Quick Reference for AI Models

This is the single-stop reference for understanding this NixOS configuration repository.

**Last updated:** 2026-09-02 | **NixOS version:** 26.05 "Yarara" | **Flake-based:** Yes

---

## What This Repo Is

A personal NixOS flake managing **3 hosts** (yoga, latitude, nix-media) with a modular architecture. Uses Home Manager, SOPS-nix secrets, Disko disk partitioning, and Btrfs impermanence.

---

## Hosts at a Glance

| Host | Hardware | Role | Special Features |
|------|----------|------|------------------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD Ryzen) | Primary laptop | Impermanence (root wiped), SecureBoot, LUKS, Btrfs, virt-manager (Windows VM) |
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
├── home/                      # Shared Home Manager: browsers, terminal, theme, git
├── pkgs/                      # Custom packages: colloid-gtk, fluent-icons, jan/zcode (AppImage)
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
| `virtualization.nix` | QEMU/KVM, libvirt, virt-manager, SPICE USB redirection |
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
  lix = true;  # true → Lix from nixpkgs (cached), false → CppNix
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
6. nixpkgs config with overlays (colloid, fluent, jan, zcode, mikromcp)

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
| `jan.nix` | Jan | AppImage wrapper via `appimageTools.wrapType2`, pinned release |
| `zcode.nix` | ZCode | AppImage wrapper via `appimageTools.wrapType2`, pinned release |
| `mikromcp.nix` | MikroMCP | Fixed nix package for the MikroTik MCP server (no npx/network at runtime) |

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
2. `nix flake update` — updates nixpkgs, nixos-hardware, home-manager, sops-nix, disko, impermanence, preload-ng
3. `nix flake check --impure --keep-going` — runs statix, deadnix, nixfmt checks
4. `nix build` — builds the host's toplevel derivation
5. Optionally activates: `test` (temporary), `boot` (next boot), `switch` (live)

Safe inputs are updated; locked inputs (lanzaboote) are NOT updated to avoid surprise breakage.

---

## Key Patterns to Follow

1. **Adding a new host:** Create `hosts/<name>/default.nix` + `home.nix` + `hardware-configuration.nix`, add to `flake.nix` outputs via `mkHost`.

2. **Adding a feature module:** Create `modules/features/<name>.nix`, import it in `modules/features/default.nix`, toggle per-host via `mkIf`.

3. **Adding a custom package:** Create `pkgs/<name>.nix`, add it to the overlay in `flake.nix` (`colloidFluentOverlays`), and consume via `pkgs.<name>` in home-manager or system packages.

4. **Secrets:** Add to `secrets/hosts/<host>.yaml` via `sops secrets`, reference in modules via `config.sops.secrets.<name>.path`.

5. **Impermanence:** Add persistent directories to `hosts/<host>/home.nix` under `home.persistence."/persist".directories`.

---

## Common Commands

```bash
# Build and switch
sudo nixos-rebuild switch --flake .#$(hostname)

# Update inputs
nix flake update

# Lint and check (pass files explicitly — bare `nix fmt` fails)
nix fmt <changed-files> && nix flake check

# Safe update (full pipeline)
./scripts/update-safe yoga switch

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
| WinApps removed | `flake.nix`, `home/`, `hosts/yoga/` | Replaced by virt-manager/libvirt |
| opencode `libstdc++.so.6` missing | `hosts/yoga/opencode.nix` | Wrap binary with `LD_LIBRARY_PATH` pointing to `stdenv.cc.cc.lib` (moved from `home/terminal.nix` when opencode config was extracted to its own module) |
| Docker 28 marked insecure | `hosts/nix-media/docker.nix` | Pin `package = pkgs.docker_29` |

**First switch after upgrade requires reboot** — dbus-broker replaces dbus-daemon, needs full restart.

### Suspend-then-hibernate (yoga)

Lid on battery suspends, then hibernates after 2h. Implemented by the `yoga-s2h` system-sleep hook (`hosts/yoga/default.nix`, installed at `/etc/systemd/system-sleep/yoga-s2h`) — **not** by `HandleLidSwitch=suspend-then-hibernate`.

**Why not systemd's built-in s2h (systemd 260):** it never hibernated on this machine — silently. Validated against `src/sleep/sleep.c` (v260) plus the journal (2026-09-03..05):

- s2h suspends with a `CLOCK_BOOTTIME_ALARM` timerfd; the kernel derives the RTC wakealarm from it, truncated to whole RTC seconds, so the machine wakes up to ~1s **before** the µsec-precision timerfd deadline.
- After the wake, `custom_timer_suspend()` polls the timerfd with zero timeout: no `POLLIN` yet → `woken_by_timer=false` → `return 0` ("manual wakeup") with no journal message. Every `woken_by_timer=true` path leads to hibernation; the kernel journal shows zero `PM: hibernation: hibernation entry` lines across every deadline wake over three days.
- The lid is still closed, so logind re-applies `HandleLidSwitch` when its 30s resume holdoff (`HoldoffTimeoutSec`) expires → fresh s2h instance → new 2h (or 1h, when the discharge-rate estimate falls back to `SuspendEstimationSec`) window. Observed: nightly 2h loops, zero hibernations, ~30s awake per cycle — the source of the extra battery drain.
- The battery-estimation path is separately broken here: capacity reports in 1% steps, so long-interval discharge estimates round to 0 and are rejected (`BAT0: Failed to update battery discharge rate, ignoring: Numerical result out of range`), and the persisted rate `/var/lib/systemd/sleep/battery_discharge_percentage_rate_per_hour` held garbage. Matches upstream reports (systemd issues #33843, #35743); if fixed upstream, the built-in can be revisited.

**The hook instead:** on every battery suspend (lid or GNOME idle — both plain `suspend`) it stores a deadline in `/run/yoga-s2h-deadline` and arms every `/sys/class/rtc/rtc*/wakealarm` (write `0` first, then the epoch value). On resume: more than 60s before the deadline → manual wake (lid open/AC: clear everything) or spurious wake (lid still closed on battery: clear only the RTC alarm, **keep the deadline** so hibernation time doesn't slide out 2h per wake; logind's holdoff re-suspends); within the window + lid still closed + still on battery → schedule the hibernate 3s out via a transient unit (`systemd-run --on-active=3s systemctl hibernate` — see the logind note below). The 60s tolerance makes the timer-vs-manual classification immune to the same second-granularity race that breaks systemd's implementation (the hook's deadline is whole seconds, same as the RTC alarm). Known limits: low battery does not trigger early hibernation (this firmware exposes no ACPI battery alarm — the reason systemd ran its estimation loop at all); if AC is plugged during suspend without waking the machine, it stays awake at the deadline (logged) rather than hibernating.

**logind refuses sleep/reboot requests made from inside sleep hooks (systemd 260):** `systemctl hibernate` called by a `post suspend` hook is always rejected — logind holds `delayed_action` until the suspend *job* completes (`match_job_removed()`), and that happens only after the post hooks exit. First observed 2026-09-06 ("Call to Hibernate failed: Action suspend-then-hibernate already in progress"), and it applies equally to plain suspends and to reboot requests. Hence the 3s deferral through a transient unit: by then the job is gone, logind accepts the request, and — crucially — it re-arms `delayed_action` plus the 30s lid holdoff for the whole hibernate write, which is the only thing preventing logind from re-triggering the still-closed lid into a concurrent suspend mid-image-write (starting `systemd-hibernate.service` directly would dodge the refusal but lose exactly that protection; logind does not track directly-started sleep units). A failed/aborted hibernate self-heals via the same deferral: `post:hibernate` records a decision and schedules a 15s `recheck` self-invocation that re-evaluates lid/AC and executes it (see the abort-handling notes below).

**sleep.conf key names (systemd 260):** the mem_sleep selector is `MemorySleepMode=`, *not* `SuspendMode=` — that key does not exist and unknown keys are silently ignored. Symptom (2026-09-07 journal): every suspend logged `PM: suspend entry (deep)` → instant exit → `PM: suspend entry (s2idle)` — the firmware rejecting S3, then systemd's own <5s-retry falling back. With `MemorySleepMode=s2idle` systemd-sleep writes `s2idle` to `/sys/power/mem_sleep` directly. (`HibernateMode=` *is* valid; `/sys/power/disk` showed `[shutdown]` selected after the 2026-09-07 04:00 hibernate.) Verify after a rebuild+reboot: `systemd-analyze cat-config systemd/sleep.conf` and a single `PM: suspend entry (s2idle)` line per suspend in the journal.

**First full-cycle telemetry (night 2026-09-07, upower history `L21D4PE0`):** lid/idle suspend 02:00:22, RTC wake at 04:00:22 *to the second*, zram swapoff + image write (534018-page snapshot ≈ 2.0G, 7.6s prealloc, ~2min reclaim), powered off ~11h, resumed 14:58 with `amdgpu SMU is resumed successfully`. **Total battery cost: 35%→34% (≈1%), implying ~0.25–0.5%/h s2idle drain — S0ix is healthy on this machine (the `rtc_cmos.use_acpi_alarm=1` cmdline is load-bearing for that), and the 2h `DELAY` is cheap.** Perceived "10% lost overnight" was actually the hour *before* the suspend: an awake session at 9–25W (a rebuild at 00:48, heavy load to ~01:45, ~9W idle desktop until GNOME's idle-suspend fired at 02:00) burned ~22% in 70min — the suspend/hibernate path itself is not the drain.

**Operational: `nixos-rebuild test` does not restart logind.** After a `test` switch, the live logind keeps its old in-memory lid policy (observed via busctl: `HandleLidSwitch` still `suspend-then-hibernate` while /etc already said `suspend`). Every lid close then runs systemd's built-in s2h, whose in-progress state blocks the hook's hibernate on top of its own timer bugs. Fix: reboot (or `systemctl restart systemd-logind`) after changing lid/sleep policy via `test`.

**Hibernation image vs zram:** the image must fit in free RAM after the kernel's own reclaim, but zram keeps swapped pages resident — at ~9.5G in use the image (8.5G) exceeded freeable RAM (7.8G) → `-ENOMEM` (2026-09-03). The hook's `pre hibernate` swaps zram out to the disk swapfile (frees the compressed pool, removes those pages from the image). **Re-enabling zram needs more than `swapon`:** `swapoff` auto-resets the zram device to disksize 0, so `swapon /dev/zram0` fails with "could not read swap header" (journal 2026-09-06). `post hibernate` instead restarts `systemd-zram-setup@zram0.service`, whose ExecStop (`--reset-device`) + ExecStart (`--setup-device`) recreate size/algorithm/priority from the NixOS-generated `zram-generator.conf` — covers real resumes, failed and aborted attempts alike.

**amdgpu/TTM hibernate instability (2026-09-06 incident, no fix upstream):** the first-ever hibernate attempt aborted *in place* — snapshot allocated, amdgpu MODE2-reset mid-device-suspend, `syscore_resume` WARNING on the unwind, no image ever written. ~20 min later the kernel oopsed in `ttm_lru_bulk_move_tail` (NULL deref via `amdgpu_cs_ioctl`), and a subsequent `DRM_GEM_CLOSE` spun on the corrupted TTM spinlock until both CPUs hard-locked (power-cycle at 01:26). This is a known amdgpu/TTM bug class — mass TTM buffer eviction under hibernate memory pressure corrupts the LRU lists; any later GPU ioctl detonates it. Tracked in drm/amd issues #5470 (root-cause analysis), #5703, #5517, #5715 (same Renoir-class GPU); **unfixed through mainline 7.3-rc1/linux-next — a kernel or zen bump will not fix it.** Mitigations applied:

- `/sys/power/image_size` capped at 4G via tmpfiles. This bounds the hibernation snapshot and thus how deep the pre-snapshot reclaim goes (the screen-dark wait): 2G gave 3.6× free-page margin (needed 860K pages, 3.1M available, 2026-09-07) but cost a 17-minute reclaim on a heavy session; 4G halves that while keeping >1.5× margin. The old ~5.9G kernel default only caused the 2026-09-03/06 ENOMEM aborts because zram kept swapped pages resident in RAM — now swapped out by the hook first, which was the real fix. Verify margins per attempt via the journal's "Normal pages needed: X, available pages: Y" lines; if Y/X drops toward ~1.2, lower the cap again. Closing memory-heavy apps before a manual hibernate still shortens the reclaim.
- `HibernateMode=shutdown` — power off via plain shutdown after writing the image, skipping the firmware's ACPI-S4 platform path (this firmware's ACPI layer is the same one with the broken S3 and the RTC wakealarm truncation bug). Verified applied on the successful 2026-09-07 cycle.
- **Hibernation is PARKED (2026-09-08, `HIBERNATE_ENABLED=0` in the yoga-s2h hook).** The full campaign: 10+ attempts across two nights, every one aborted in-place in the kernel freeze pass (`usb 3-3: WARN: invalid context state`, deep amdgpu unwind — the drm/amd #5470 TTM-corruption precondition), regardless of USB device/controller state (bound+active, interface-unbound, device-unbound → `usb_dev_restore -107` instead, bound+runtime-suspended via rfkill, `authorized 0→1` re-enumeration, full `xhci_hcd` driver rebind of `0000:04:00.4`) and regardless of bridging through a suspend cycle first (the 10s self-wake bridge — the single 04:00 success never reproduced). **The aborts are also self-amplifying:** the failed freeze resets input devices and the re-enumeration emits phantom power-button events (`gnome-shell: libinput error: event2 - Power Button`), which GNOME converts into fresh hibernate requests — an abort→hibernate→abort loop until hard power-off (2026-09-08 00:20–00:21). Current policy: **suspend-only** (s2idle measured ≈0.25–0.5%/h → a full night ≈3–4%) — a plain unbounded s2idle, no RTC timer while parked (a 2h wake-and-re-suspend cycle would cost ~0.4% per wake for nothing; the timer logic re-arms automatically when `HIBERNATE_ENABLED=1`). Abort detection + depth-aware response remain for manual `systemctl hibernate` tests. Re-enable by flipping `HIBERNATE_ENABLED=1` after a kernel (try non-zen), BIOS/fwupd update, or upstream fix; the abort detector now requires **uptime growth ≥30s AND wall-vs-uptime skew <60s** (a real resume's restored uptime also contains the frozen reclaim+write time, so uptime alone would misread every clean resume as a deep abort → auto-reboot after success; and a fast 40s abort slipped under the old 45s cutoff).
- **Automated abort response (verified live 2026-09-07 22:02):** `post:hibernate` detects an in-place abort via `/proc/uptime` growth during the attempt (>45s ⇒ the whole reclaim/snapshot/unwind ran in this kernel; a real resume restores the frozen clock and only seconds pass). This is necessary because the kernel can abort *and still return success* from the `/sys/power/state` write — at 2026-09-06 23:38 `systemd-hibernate.service` never entered failed state and logged no error, so `systemctl is-failed` (kept as a secondary trigger for systemd-level failures like the 2026-09-03 ENOMEM) is blind to kernel aborts. On the 22:02 deep abort the hook correctly logged "hibernate aborted AFTER amdgpu suspend (TTM corruption risk)" within a second. Response is depth-aware: if the kernel log since the attempt started contains `SMU is resuming`, amdgpu went down and was unwound — the exact Sep-6 corruption precondition — so unattended (lid closed, battery) the hook reboots after 15s and `wall`s a warning if the user is present; a shallow abort (no amdgpu involvement, like 23:38) just re-suspends and retries in 2h. Caveat learned at 22:02: **`wall` does not reach a GNOME session** — an aborted manual hibernate just drops you back on the desktop looking "successful". Rule of thumb: if a manual hibernate returns you to the desktop instead of powering the machine off, it aborted — reboot promptly.
- Operational rule (still true for manual tests): **after any hibernate attempt that aborts in place (journal shows `hibernation exit` in the same boot, no power-off), reboot promptly** — the automated path covers unattended cycles, but a manually-triggered abort with the lid open only warns.

**Impermanence rollback vs hibernate resume:** `rollback-root` (initrd, `modules/features/impermanence.nix`) wipes and recreates `@` on every boot and originally had no ordering against `systemd-hibernate-resume.service` — on a resume boot the two raced (journal shows "Deleting subvolume" interleaved with the resume attempt), which would put a resumed session's writes into a deleted subvolume. `rollback-root` is now ordered `After=systemd-hibernate-resume.service`: on a real resume the kernel jumps into the restored image during that unit and the initrd (hence the wipe) never finishes; on normal boots the unit fails fast ("Image not found") and the wipe proceeds — ordering against a failed unit doesn't block.

**NixOS hook PATH pitfall:** system-sleep hooks run with a minimal PATH — `grep` was missing (`grep: command not found` in the journal) while `swapon` happened to resolve. The hook sets `PATH` explicitly via `lib.makeBinPath`.

**Agent pitfall — the ZCode shell does not see the host's `/etc`:** agent tool shells run sandboxed inside the ZCode fhsenv, which bind-mounts its own `/etc/systemd` (and friends) over the host paths (`findmnt /etc/systemd` shows a `zcode-…-fhsenv-rootfs` source; `sudo` is blocked by `no_new_privileges`). Checking live config files like `/etc/systemd/sleep.conf` from an agent shell therefore gives *wrong answers*. Host truth: journalctl output, `/run/current-system` / `/run/booted-system` store paths, and `/sys` (which passes through) — verify applied sleep config via the journal (`PM: suspend entry (s2idle)`, single line per suspend) rather than `systemd-analyze cat-config` from the sandbox.

**Prereq:** `resumeDevice` + `resume_offset=7697093` (via `btrfs inspect-internal map-swapfile -r /var/lib/swap/swapfile` — re-derive if the swapfile is ever recreated; stale offset = boots fresh instead of resuming, no corruption).

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
| Windows VM (virt-manager) | `modules/features/virtualization.nix` |
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
