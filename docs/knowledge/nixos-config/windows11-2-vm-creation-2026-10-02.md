---
name: windows11-2-vm-creation-2026-10-02
description: windows11-2 (26H2) created then SWAPPED into the windows11 identity
  2026-10-02 — old VM deleted, rename mechanics, what's still open
metadata:
  node_type: memory
  type: project
  originSessionId: sess_091a9e7e-321e-4148-8e2a-78064dfaab9e
---

2026-10-02 full VM lifecycle, DONE: fresh 26H2 VM built from the windows11 XML template (see [[virtualization-audit-2026-09-30]] for hardware provenance: q35, UEFI secure firmware enrolled-keys=no, emulated TPM 2.0, virtio everywhere, memballoon=none), user verified iTunes, then the swap was EXECUTED same day:

**Old windows11 deleted**: `virsh undefine windows11 --snapshots-metadata --nvram` (killed pre-virtio-video snapshot + old VARS) + `virsh vol-delete win11.qcow2` (181 G freed). User-requested, no fallback after this.

**Rename windows11-2 → windows11** (both VMs were already off): disk `mv win11-2.qcow2 win11.qcow2` + `pool-refresh default` (dir rename needs only dir-write perm, worked from agent shell); NVRAM preserved via `pool-refresh nvram` + `vol-clone windows11-2_VARS.fd windows11_VARS.fd` (nvram dir NOT agent-writable — vol-clone through the pool is the workaround; preserves boot entries/TPM sealing, avoids BitLocker risk); `virsh undefine windows11-2 --nvram` (plain undefine REFUSES on domains with varstore — "Cannot undefine domain with NVRAM/varstore"); define /tmp/windows11-new.xml with name=windows11, MAC reverted to `52:54:00:03:b9:49` (inherits .139 + SSH/mcp wiring), installer cdrom device dropped (= the ISO eject; **file kept at /var/lib/libvirt/images/win11-26h2-en.iso, 11 G, deletable on request**), vda boot order 1, fresh uuid.

**Verified**: boots to desktop (virsh screenshot → PNG → image analysis), DHCP lease `192.168.122.139` hostname windows11.

**Nix** (staged, not committed): guests = `windows11` ONLY — windows11-2 AND win11-work entries removed (win11-work was never created; runbook lives in git history). .140/.141 reservations vanish from the generated network XML → drift unit applies on next boot/switch with no VMs running (defers while windows11 runs — stale dnsmasq reservations are harmless until then). Stale WinApps `~/.local/share/applications/windows.desktop` (dated Apr 3, impermanence-persisted, RDP-session launcher) deleted — was the mystery "windows" launcher entry; "windows11-2" sightings were virt-viewer window titles, never .desktop files. QC green (flake check + dry-build yoga).

**Open**: the fresh Windows install has NO OpenSSH/windows-mcp yet — SSH bootstrap recipe in [[windows11-vm-remote-access-guide]] must be redone inside the guest (wiring on host side already targets .139 and is unchanged).
