# Plymouth Graphical LUKS Screen — Issue Analysis & Fix

## Affected Hosts

- **yoga** — Lenovo Yoga Slim 7 Pro Gen8 (AMD Ryzen, YELLOW_CARP iGPU)
- Any AMD host with `hardware.amd-gpu.enable = true` + `core.boot.silent = true` + LUKS encryption

## Problem Statement

The graphical Plymouth LUKS password prompt appears intermittently — sometimes the boot
splash renders correctly and the passphrase prompt is shown inside it, other times the
screen falls back to a text-mode console prompt. The behavior varies between reboots on
the same hardware with no config changes.

## Root Cause

Plymouth's DRM device detection has an **8-second timeout** for "simpledrm" devices
(`/run/plymouth/plymouthd.conf`: `DeviceTimeout=8`). During early boot:

1. The kernel initializes `simpledrm` first (EFI framebuffer, card0)
2. Plymouth starts and finds the simpledrm device
3. Plymouth **deliberately ignores** simpledrm, waiting for a "real" DRM driver (amdgpu)
4. After 8 seconds, Plymouth falls back to simpledrm anyway

Meanwhile, `amdgpu` is loading in initrd (via `boot.initrd.kernelModules`). The time
amdgpu takes to initialize varies per boot due to firmware loading latency, making the
race between Plymouth's timeout and amdgpu readiness non-deterministic.

### Why `plymouth.use-simpledrm` alone was insufficient

When `plymouth.use-simpledrm` was used **without** the `systemd-cryptsetup@` ordering:

```
1. Plymouth starts immediately with simpledrm
2. amdgpu loads and performs a modeset (takes over the DRM device)
3. Plymouth loses its simpledrm display
4. systemd-cryptservice starts — but Plymouth is dead
5. LUKS prompt appears in text mode
```

The LUKS prompt appeared before Plymouth could serve it through its graphical interface.

### Why amdgpu-in-initrd alone was insufficient

When amdgpu was loaded in initrd **without** `plymouth.use-simpledrm`:

```
1. Plymouth starts, ignores simpledrm, waits 8s for amdgpu
2. If amdgpu firmware loads fast → Plymouth finds amdgpu → graphical prompt works
3. If amdgpu firmware loads slow → Plymouth falls back after 8s → inconsistent state
```

## The Fix (commit `466d491`)

Three changes work together:

### 1. `plymouth.use-simpledrm` kernel param

```nix
# modules/core/boot.nix:58
"plymouth.use-simpledrm"
```

Forces Plymouth to use the simpledrm framebuffer immediately. No 8-second wait.

### 2. amdgpu in initrd

```nix
# modules/hardware/amd-gpu.nix:19
boot.initrd.kernelModules = [ "amdgpu" ];
```

Loads amdgpu early so it's available as soon as possible (also provided by
`nixos-hardware/lenovo-yoga-7-slim-gen8`).

### 3. systemd-cryptsetup ordering

```nix
# modules/core/boot.nix:42
systemd.services."systemd-cryptsetup@".after = [ "plymouth-start.service" ];
```

Ensures the LUKS passphrase prompt is deferred until Plymouth is running.

### Boot sequence with the fix

```
Kernel loads
  → simpledrm initializes (card0)
  → amdgpu loads in initrd (card1)
  → Plymouth starts, immediately uses simpledrm
  → systemd-cryptsetup waits for plymouth-start.service
  → LUKS prompt renders through Plymouth (simpledrm)
  → User enters password, disk unlocks
  → amdgpu finishes init, modesets (brief flicker, cosmetic only)
  → Stage 1 completes, GDM starts
```

The LUKS prompt is served before the amdgpu modeset, so the display handoff
doesn't interfere with the passphrase entry.

## Configuration History

| Date | Commit | use-simpledrm | amdgpu initrd | cryptsetup ordering | Result |
|------|--------|:---:|:---:|:---:|--------|
| Feb 11 | `f8d7652` | yes | amd-gpu + nixos-hardware | no | Prompt sometimes killed by amdgpu modeset |
| Mar 12 | `be78763` | commented out | amd-gpu + nixos-hardware | no | 8s race, inconsistent |
| Mar 18 | `e235ec2` | yes | nixos-hardware only | no | Still broken — nixos-hardware loads amdgpu regardless |
| Jun 1 | `8754a7f` | removed | amd-gpu + nixos-hardware | **yes** | 8s race still present |
| Jun 5 | `466d491` | **yes** | amd-gpu + nixos-hardware | **yes** | **Fixed** |

## Key Insight

The missing piece in earlier attempts was the `systemd-cryptsetup@` ordering. Without it,
the LUKS prompt races against Plymouth startup regardless of which DRM backend Plymouth
uses. With the ordering in place, `plymouth.use-simpledrm` works reliably because
Plymouth has a display device from t=0 and the prompt is guaranteed to wait for it.

## Verification

After rebuilding, check on the yoga:

```bash
# Confirm kernel params include use-simpledrm
cat /proc/cmdline | grep -o 'plymouth.use-simpledrm'

# Confirm Plymouth daemon config
cat /etc/plymouth/plymouthd.conf
# Should show: Theme=bgrt, DeviceTimeout=8

# Check boot log for simpledrm → amdgpu handoff
journalctl -b -o cat | grep -E "simpledrm|amdgpu.*modeset|card[01]"

# Check Plymouth service started
systemctl status plymouth-start.service
```

## References

- [NixOS/nixpkgs#266804](https://github.com/NixOS/nixpkgs/issues/266804) — systemd-stage-1 Plymouth password prompt delay
- [NixOS Discourse: Plymouth stopped showing up in 25.11](https://discourse.nixos.org/t/plymouth-stopped-showing-up-in-nixos-25-11/73136)
- [NixOS/nixpkgs#26722](https://github.com/NixOS/nixpkgs/issues/26722) — Plymouth LUKS prompt with encrypted root
- Plymouth source: `ply-device-manager.c:400` — "ignoring since we only handle SimpleDRM devices after timeout"
