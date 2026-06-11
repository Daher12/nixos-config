# Plymouth Graphical LUKS Screen — Issue Analysis & Fix

## Affected Hosts

- **yoga** — Lenovo Yoga Slim 7 Pro Gen8 (AMD Ryzen, YELLOW_CARP iGPU)
- Any AMD host with `hardware.amd-gpu.enable = true` + `core.boot.silent = true` + LUKS encryption

## Problem Statement

The graphical Plymouth LUKS password prompt appears intermittently — sometimes the boot
splash renders correctly and the passphrase prompt is shown inside it, other times the
screen falls back to a text-mode console prompt. The behavior varies between reboots on
the same hardware with no config changes.

Observed pattern on yoga:

- Cold boot (power off → on) → LUKS splash renders ✓
- Reboot (warm) → LUKS splash fails, text-mode prompt ✗

The pattern is fully deterministic per boot class — what changes is firmware load latency,
which depends on disk-cache and CPU-cache warmth.

## Root Cause

**`amdgpu` loaded in initrd unregisters `simpledrm` before Plymouth can attach to it.**

When the `amdgpu` kernel module probes the GPU (which happens automatically as soon as
the module is loaded by `systemd-modules-load.service` in `sysinit.target`), the driver
calls `drm_aperture_remove_conflicting_framebuffers()` to claim the display. This
**unregisters the `simpledrm` platform device entirely** — not just hides it; the
underlying platform device and its `/dev/dri/card0` node are torn down.

By the time `plymouth-start.service` runs `plymouthd`, `simpledrm` is gone, and
`plymouthd` has no DRM device to attach to. Plymouth's `use-simpledrm` logic
(source: `ply-device-manager.c` → `use_simpledrm_device()`) is a **predicate** that
returns true only when **both** the kernel cmdline arg is set **and** a simpledrm
candidate device is present in the udev enumeration. With simpledrm gone, the
predicate is false and Plymouth falls back to its native-DRM wait path, eventually
hitting the 8s `DeviceTimeout` and giving up to text mode.

### Why cold boot works and reboot fails

| Boot type | amdgpu firmware | amdgpu probe time | simpledrm status at Plymouth start |
|-----------|-----------------|-------------------|------------------------------------|
| Cold boot | loaded from disk | ~3–5s (firmware I/O) | still registered (amdgpu probe pending firmware) |
| Reboot    | warm in CPU/RAM caches | <1s | already removed before plymouth-start runs |

The hardware always does the same things in the same order; the variability is
firmware load latency, a function of disk-cache state, CPU cache warmth, and memory
page residency. This is what makes the failure appear "random" while being fully
deterministic per boot class.

### Why the NixOS Plymouth config can't paper over this

Plymouth's `DeviceTimeout=8` is **not** the source of the failure. The
`use-simpledrm` flag is supposed to bypass the timeout and attach immediately, but
it cannot attach to a device that no longer exists. The timeout only matters for
the fallback path that *also* finds no device and gives up to text mode.

## Why the previous fix (`466d491`) did not work

The 466d491 commit combined three changes, two of which contradict the third:

1. `boot.initrd.kernelModules = [ "amdgpu" ]` (in `modules/hardware/amd-gpu.nix:19`
   and via `nixos-hardware/lenovo/yoga/7/slim/gen8`)
2. `boot.kernelParams = [ "plymouth.use-simpledrm" ]` (in `modules/core/boot.nix:58`)
3. `systemd.services."systemd-cryptsetup@".after = [ "plymouth-start.service" ]`
   (in `modules/core/boot.nix:42`)

Changes (1) and (2) are mutually exclusive: amdgpu loading in initrd removes the
simpledrm device that (2) tells Plymouth to use. Change (3) is correct in concept
(the LUKS prompt must wait for Plymouth to be ready) but cannot help if Plymouth
has no display to serve the prompt through.

Additionally, `amdgpu` is added to `boot.initrd.kernelModules` by **two**
sources on yoga, and udev auto-loads it via PCI modalias regardless of
both:

- `modules/hardware/amd-gpu.nix:19` — local module
- `nixos-hardware/lenovo/yoga/7/slim/gen8/default.nix:3` — direct (yoga profile)

Removing `amdgpu` from `initrd.kernelModules` is necessary but not
sufficient — the initcall blacklist is what actually prevents loading.

## Proposed Fix

Two changes. The core fix is blacklisting `amdgpu` in the initrd so that
`simpledrm` survives and Plymouth attaches to it deterministically.

### 1. Blacklist `amdgpu` in initrd kernel params

udev's PCI modalias auto-detection loads `amdgpu` during kernel PCI
enumeration — **before** `systemd-modules-load.service` runs. Removing
`amdgpu` from `boot.initrd.kernelModules` alone does not prevent this.
The driver must be blocked at the initcall level:

```nix
# hosts/yoga/default.nix — inside the existing `boot = { ... }` block
boot = {
  loader.timeout = 0;
  initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  initrd.kernelModules = [ "btrfs" "dm_mod" "kvm" "kvm-amd" ];  # no amdgpu
  kernelModules = [ "ryzen_smu" ];
  extraModulePackages = [ config.boot.kernelPackages."ryzen-smu" ];
  kernelParams = [
    "initcall_blacklist=amdgpu_init"  # prevent amdgpu probe in initrd → keeps simpledrm alive
  ];
};
```

**Why `initcall_blacklist` and not `module_blacklist`:**
`module_blacklist=amdgpu` prevents `modprobe` from loading the module, but
udev can still load it directly via `modules-load` or implicit modalias
resolution. `initcall_blacklist=amdgpu_init` prevents the driver's
`module_init` function from executing even if the module is loaded, which
is the only reliable way to stop it from calling
`drm_aperture_remove_conflicting_framebuffers()`.

**What gets preserved:** `btrfs`, `dm_mod`, `kvm`, `kvm-amd` stay in
`initrd.kernelModules`. Only `amdgpu` is removed. The previous
`lib.mkForce [ ]` approach would have destroyed these — both are required
for LUKS+Btrfs root mounting.

**amdgpu still loads after switch-root.** In the real root, standard
PCI/udev handling loads `amdgpu` normally. No stage-2 functionality is
lost.

### 2. Keep existing config (no changes needed)

- **`plymouth.use-simpledrm`** (`modules/core/boot.nix:58`) — stays. Now
  works because simpledrm survives the entire stage-1 sequence.
- **`systemd-cryptsetup@` after `plymouth-start.service`**
  (`modules/core/boot.nix:42`) — stays. Guarantees LUKS prompt waits for
  Plymouth.
- **`modules/hardware/amd-gpu.nix`** — unchanged. The shared module is
  correct as a generic early-KMS-amdgpu preset. The yoga-specific LUKS +
  Plymouth requirement justifies a host-level override, not a shared
  module change.

### Alternative considered: disable simpledrm instead

The opposite approach — `initcall_blacklist=simpledrm_platform_driver_init`
— prevents simpledrm from loading, so amdgpu gets `card0` directly and
Plymouth attaches without the 8s timeout. This avoids the
simpledrm→amdgpu handoff entirely. Some distributions use this approach.
However, the Fedora 42 approach (blacklist amdgpu, keep simpledrm) is
preferred here because it matches upstream direction and provides a clean
stage-1→stage-2 handoff.

## Expected boot sequence with the fix

```
Kernel loads
  → simpledrm initializes (card0) — only DRM device
  → systemd-modules-load.service runs (no amdgpu module to load)
  → plymouth-start.service starts plymouthd
  → plymouthd sees plymouth.use-simpledrm + simpledrm present → attaches immediately
  → systemd-cryptsetup@ waits for plymouth-start.service (per boot.nix:42)
  → LUKS prompt renders through Plymouth on simpledrm
  → User enters passphrase, disk unlocks
  → initrd switch-root to real system
  → systemd in real root loads amdgpu via standard PCI/udev handling
  → amdgpu modesets (single flicker, then stable)
  → Plymouth quits, GDM starts on amdgpu
```

The LUKS prompt is served before `amdgpu` is ever loaded, so the modeset handoff
cannot interfere with passphrase entry. This matches what Fedora 42 adopted as the
default behaviour for the same reason (see `Changes/PlymouthUseSimpledrm`).

## Configuration History

| Date | Commit | use-simpledrm | amdgpu initrd | cryptsetup ordering | Result |
|------|--------|:---:|:---:|:---:|--------|
| Feb 11 | `f8d7652` | yes | amd-gpu + nixos-hardware | no | Prompt sometimes killed by amdgpu modeset |
| Mar 12 | `be78763` | commented out | amd-gpu + nixos-hardware | no | 8s race, inconsistent |
| Mar 18 | `e235ec2` | yes | nixos-hardware only | no | Still broken — nixos-hardware loads amdgpu regardless |
| Jun 1 | `8754a7f` | removed | amd-gpu + nixos-hardware | **yes** | 8s race still present (no use-simpledrm) |
| Jun 5 | `466d491` | **yes** | amd-gpu + nixos-hardware | **yes** | **Broken** — amdgpu removes simpledrm, use-simpledrm cannot help |
| Proposed | — | **yes** | **no** (initcall blacklist) | **yes** | **Expected fix** — amdgpu init blocked in initrd, simpledrm survives, Plymouth attaches deterministically |

## Key Insight

The chain that fails is:

```
amdgpu in initrd
  → drm_aperture_remove_conflicting_framebuffers() on probe
  → simpledrm platform device unregistered
  → use_simpledrm_device() predicate is false (no candidate)
  → Plymouth falls through to native-DRM wait
  → amdgpu still initializing
  → 8s DeviceTimeout
  → text-mode fallback
```

The 466d491 fix treated `use-simpledrm` as a **switch** that *enables* simpledrm
support. It is actually a **predicate** that *requires* simpledrm to exist. The two
are not the same on systems with a native GPU driver that is loaded in initrd.

The NixOS upstream `hardware.amdgpu.initrd.enable` option exists for systems that
want a high-resolution real-KMS boot splash (its docstring: "Can fix lower
resolution in boot screen during initramfs phase"). On a laptop with Plymouth +
LUKS, the boot-splash resolution is irrelevant — what matters is that **the prompt
renders at all**, and that requires simpledrm to be the only DRM device during
stage 1.

## Verification

After rebuilding yoga, check the following on a fresh boot:

```bash
# 1. amdgpu must NOT be in the initrd cpio
sudo lsinitrd /nix/store/*-initrd-linux-*/initrd 2>/dev/null \
  | grep -E 'amdgpu\.ko|simple-framebuffer\.ko' \
  | sort -u
# Expected: only simple-framebuffer.ko

# 2. cmdline should still have use-simpledrm
cat /proc/cmdline | tr ' ' '\n' | grep plymouth
# Expected: plymouth.use-simpledrm

# 3. Boot order: simpledrm Registered → plymouth Attached → cryptsetup Start
journalctl -b -o cat | grep -E \
  "simple-framebuffer.*Registered|plymouth.*Attached|systemd-cryptsetup.*started"
# Expected order matches that sequence

# 4. Plymouth config sanity
cat /etc/plymouth/plymouthd.conf
# Expected: Theme=bgrt, DeviceTimeout=8

# 5. LUKS prompt timing should be deterministic across N reboots
for i in $(seq 1 5); do sudo systemctl reboot; sleep 30; \
  journalctl -b -1 -o cat | grep -q 'plymouth.*Attached' && echo "boot $i: ok" || echo "boot $i: FAIL"; done
```

## References

- [NixOS/nixpkgs#266804](https://github.com/NixOS/nixpkgs/issues/266804) — systemd-stage-1 Plymouth password prompt delay
- [NixOS Discourse: Plymouth stopped showing up in 25.11](https://discourse.nixos.org/t/plymouth-stopped-showing-up-in-nixos-25-11/73136)
- [NixOS/nixpkgs#26722](https://github.com/NixOS/nixpkgs/issues/26722) — Plymouth LUKS prompt with encrypted root
- [Fedora Changes/PlymouthUseSimpledrm](https://fedoraproject.org/wiki/Changes/PlymouthUseSimpledrm) — same approach adopted as default in Fedora 42
- [ArchWiki: Plymouth — Using SimpleDRM](https://wiki.archlinux.org/title/Plymouth#Using_SimpleDRM) — recommended for "systems with AMD GPUs"
- Plymouth source: `ply-device-manager.c` → `use_simpledrm_device()` — `plymouth.use-simpledrm` is a *predicate* requiring simpledrm to exist, not a *switch* that enables it
- Linux DRM: `drm_aperture_remove_conflicting_framebuffers()` — what `amdgpu` calls on probe to claim the display

---

## Critical Evaluation of External Troubleshooting Session

An independent troubleshooting session produced findings that overlap with but also
contradict parts of this document. Below is a point-by-point evaluation.

### What's correct

**`drm_aperture_remove_conflicting_framebuffers()` unregisters simpledrm entirely.**
Verified against kernel source. This is a full device unregister via
`platform_device_unregister()`, not just framebuffer removal. `/dev/dri/card0`
disappears. The `plymouth.use-simpledrm` predicate becomes false once this happens.

**The race between amdgpu probe and Plymouth device scan is real.** Boot log
evidence from yoga confirms simpledrm registers first (card0, minor 0), then amdgpu
takes over (card1). The question is whether Plymouth connects to simpledrm before
amdgpu removes it.

**`systemd-modules-load` and `plymouth-start` have no explicit ordering.**
Verified from the unit file. `plymouth-start.service` runs
`After=systemd-udev-trigger.service` with `DefaultDependencies=no`.
`systemd-modules-load.service` runs `Before=sysinit.target`. No dependency links
them — a genuine race.

### What's wrong or imprecise

**"Three sources" of amdgpu in initrd is incorrect for yoga.** The external
session claims `nixos-hardware/common/gpu/amd/default.nix` contributes a third
source via `hardware.amdgpu.initrd.enable = lib.mkDefault true`. This is wrong:

```bash
nix eval .#nixosConfigurations.yoga.config.hardware.amdgpu.initrd.enable
→ false
```

The yoga module (`lenovo/yoga/7/slim/gen8/default.nix`) does **not** import
`common/gpu/amd`. It directly sets `boot.initrd.kernelModules = [ "amdgpu" ]`.
Only **two** sources add amdgpu:

1. `modules/hardware/amd-gpu.nix:19`
2. `nixos-hardware/lenovo/yoga/7/slim/gen8/default.nix:3`

**"amdgpu loads during sysinit.target via systemd-modules-load" — likely wrong.**
The kernel ring buffer shows amdgpu messages (PCI probe, modesetting init) **before**
the `Runtime Journal` line (systemd-journald starting in initrd). This means amdgpu
is loaded by **udev modalias auto-detect during kernel PCI enumeration**, not by
`systemd-modules-load`. This has a critical implication:

> Removing amdgpu from `boot.initrd.kernelModules` does **not** prevent it from
> loading in initrd. udev still loads it via PCI modalias. To actually prevent it,
> you need `module_blacklist=amdgpu` in the initrd kernel params — or prevent
> simpledrm from loading in the first place (the opposite approach).

**`lib.mkForce [ ]` would break boot.** The actual initrd kernelModules are:

```json
["amdgpu","btrfs","dm_mod","kvm","kvm-amd"]
```

Using `lib.mkForce [ ]` removes `btrfs` and `dm_mod` — both required for
LUKS+Btrfs root mounting. The system would fail to boot. A surgical override would
need to preserve the non-amdgpu modules:

```nix
boot.initrd.kernelModules = lib.mkForce [ "btrfs" "dm_mod" "kvm" "kvm-amd" ];
```

But this is fragile and would break if other modules are added later.

**The cold-boot vs reboot theory is speculative.** The external session presents
a table claiming firmware load latency explains the cold-boot vs reboot difference.
There is no evidence for this specific mechanism. The timing variations are more
likely caused by systemd's parallel service startup non-determinism, udev event
ordering, and CPU cache state — not specifically firmware cold vs warm loading.
The pattern may exist, but attributing it to firmware cache warmth is unproven.

### What this changes about the proposed fix

The external session's proposed fix (remove amdgpu from initrd) is directionally
correct but has implementation problems:

1. **udev auto-loads amdgpu anyway** — PCI modalias matching happens before
   systemd-modules-load. `boot.initrd.kernelModules` is not the only path amdgpu
   takes into the initrd. A `module_blacklist=amdgpu` kernel param (in the initrd
   only) would be more reliable, or alternatively `initcall_blacklist=amdgpu_init`
   to prevent the driver's module_init from running.

2. **`lib.mkForce [ ]` destroys btrfs/dm support** — must preserve those modules.

3. **The `systemd-cryptsetup@` ordering (commit `466d491`) is still valuable** —
   even if Plymouth falls back to the 8s timeout and attaches to amdgpu directly,
   the ordering ensures the LUKS prompt waits for Plymouth to be ready. Removing it
   would regress the text-mode case.

### Revised understanding of current state

Given that amdgpu loads via udev modalias (before systemd-modules-load), the current
boot sequence on yoga is:

```
Kernel PCI enumeration
  → udev modalias loads amdgpu
  → amdgpu probes GPU
  → drm_aperture_remove_conflicting_framebuffers() removes simpledrm
  → simpledrm card0 gone
systemd starts in initrd
  → plymouth-start.service runs
  → scans for DRM devices: no simpledrm, waits for amdgpu
  → 8s DeviceTimeout, re-enumerates, finds amdgpu card1
  → Plymouth attaches to amdgpu
  → systemd-cryptsetup@ (after plymouth-start) → LUKS prompt via amdgpu
```

This means `plymouth.use-simpledrm` is currently a **no-op** on yoga — simpledrm is
always gone before Plymouth starts. Plymouth ends up using amdgpu after the timeout.
The `systemd-cryptsetup@` ordering is what makes it work at all, but there is always
an ~8s delay before the prompt appears.

The fix must either:
- **(A)** Prevent amdgpu from loading in initrd (blacklist it), so simpledrm
  survives and `use-simpledrm` works, OR
- **(B)** Prevent simpledrm from loading (`initcall_blacklist=simpledrm_platform_driver_init`),
  so amdgpu gets card0 directly and Plymouth attaches to it without the 8s timeout

Option (B) is actually what some distributions do — it avoids the simpledrm→amdgpu
handoff entirely. Option (A) is what Fedora 42 does. Both are valid.
