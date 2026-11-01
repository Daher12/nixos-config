---
name: latitude-disko-opencode
description: latitude disko migration (ext4 kept) + opencode shared module
  STAGED on testing 2026-09-17, QC green; live machine needs GPT partlabel
  relabel before first rebuild or initrd can't unlock LUKS
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b41281f9-e28d-4664-bbb0-64d8cea10e82
---

2026-09-17, branch `testing`, staged uncommitted (per house rules): latitude became
disko-declarative — `hosts/latitude/disks.nix` (ESP 2G EF00 → /boot; LUKS partition
labeled `cryptroot`, mapper name `nixos` kept = live install's name → ext4 `/` with
noatime,nodiratime,commit=30; `settings.allowDiscards = true` so fstrim finally
discards through dm-crypt; disk device `/dev/sda` = SATA M.2, format-time only,
runtime mounts go by-partlabel; no swapDevices — zram from laptop profile, eval'd 0).
ext4 deliberately kept over btrfs (dual-core Broadwell + SATA link; impermanence
module is btrfs-only and unused here; fsck = simplest recovery) — rationale lives in
the disks.nix header. `hosts/latitude/hardware-configuration.nix` stripped to
drivers/microcode only. opencode extracted to shared `home/opencode.nix` with
`opencode.enable` opt-in (like browsers.*); `hosts/yoga/opencode.nix` is now just
enable + impermanence persistence; latitude home.nix opts in (needs one
`opencode auth login` on first use).

QC 2026-09-17 all green: `nix flake check`, dry-build latitude AND yoga, and yoga's
generated opencode.json byte-identical to the deployed one (extraction proven
behavior-preserving).

Non-obvious repo facts that cost digging: `home.persistence` evaluates on ALL hosts
because `modules/features/impermanence.nix` imports the impermanence NixOS module
unconditionally (it injects the HM option); `programs.opencode` is an upstream
home-manager module — no repo code provides it.

Impermanence for latitude — EVALUATED 2026-09-17, verdict SKIP (user rule: add if
neutral/positive, skip if negative → clearly negative here, no code change). The
full rationale lives only in this conversation (disks.nix header carries only the
btrfs-only half): (1) repo impermanence is btrfs-only with a hard
`fsType == "btrfs"` assertion + initrd @blank-snapshot rollback — an ext4 path
means repartition (separate persist volume = reinstall) plus a new initrd
mkfs-wipe mechanism that exists nowhere in the repo, and btrfs = the already-
rejected CPU/SATA trade; (2) benefit/risk inverts on a legacy host — state
hygiene pays on yoga (daily experiment surface), latitude accumulates little
drift, while the failure mode (one forgotten persistence entry silently eats
state: wifi, browser session, opencode auth) bites hardest on a sporadically
used machine; (3) NixOS bootloader generations already give the valuable half
(system rollback, fs-independent); (4) sops coupling: enabling
`features.impermanence` flips latitude's key.txt lookup to
`/persist/system/var/lib/sops-nix` (sops.nix persistPrefix) — would entangle the
still-pending latitude re-encryption. Cheap approximation if ever wanted: GC is
already on via laptop profile; `--rollback` + periodic rsync of a few state dirs
covers realistic failure modes.

**Why:** the live latitude still runs the pre-disko install whose partitions carry no
GPT partlabels; the new config mounts by `by-partlabel/ESP` and `by-partlabel/cryptroot`,
so a rebuild+reboot before relabeling = unbootable initrd. The repo docs (disks.nix
header, REPO_OVERVIEW § Known Gotchas "Disko adoption without reinstall") carry the
how-to, but nothing there tracks that the operator action is still PENDING.

**How to apply:** before the user rebuilds/switches the live latitude on this staged
state: either `sudo sgdisk --change-name=1:ESP --change-name=2:cryptroot /dev/sda`
(verify partition order via lsblk first; metadata-only) or full reinstall via
`scripts/install.sh latitude` (disko labels at format time). install.sh was
FIXED 2026-09-17 (same session — see [[install-sh-audit-2026-09-17]]), so the
reinstall branch is now only blocked on commit+push (install.sh clones from the
remote); latitude's clean-first-boot prerequisite = backup USB including
`sops/key.txt`. The staged index also
holds unrelated parallel work — [[yoga-dmcub-firmware-regression]] firmware pin and
[[hyprland-dms-setup]] Hyprland feature — so any future commit bundles them unless
the user separates them.
