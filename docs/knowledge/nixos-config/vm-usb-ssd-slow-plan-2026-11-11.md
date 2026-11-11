---
name: vm-usb-ssd-slow-plan-2026-11-11
description: Windows11 VM external USB3 SSD crawls <5 MB/s — scan+diagnosis+full
  troubleshooting plan 2026-11-11, PLAN ready ExitPlanMode DENIED nothing
  executed; TLP USB_AUTOSUSPEND prime suspect
metadata:
  node_type: memory
  type: project
  originSessionId: session_1c1ddc173441a2e384e2415f693e8032
---

2026-11-11 plan-mode session: user reported "some devices" with bad transfer speeds into the windows11 VM; AskUserQuestion narrowed it to **external USB3 drive/SSD at <5 MB/s** (dramatically wrong — native 300+, even spice redirect should do 30-100).

**Scan findings (read-only, verified live):**
- VM config EXONERATED: virtio disk (cache=none/io=native/discard=unmap on LUKS→btrfs NVMe, NOCOW dir), virtio NIC, **qemu-xhci** (USB3, 15 ports), 2 spicevmc redirdev channels (no redirfilter), spice image-compression off, virtio-gpu. VM was **shut off** (clean shutdown 23:43 same day); agent has libvirtd group (virsh dumpxml works).
- **PRIME SUSPECT: TLP USB_AUTOSUSPEND=1** — `modules/features/power-tlp.nix:32` mkDefault, NOT overridden on yoga, and `TLP_DEFAULT_MODE="BAT"` (hosts/yoga/default.nix:250) → autosuspend applies even on AC.
- hostdev `14cd:1212` = **Super Top SY-T18 microSD card reader, USB2, ~18 MB/s ceiling** (web-verified) — permanently assigned in XML but was NOT plugged in; expectation-setting only, hardware is the cap there.
- Host USB: 10G ports free (usb2/4/7/9 = 10000M root hubs); host uplink wlan0 only; no 9p/virtio-fs/SMB shares exist → host↔VM copies only via virbr0.
- Domain XML is manual state (NOT repo); only guest wiring (guests attrset, launchers, network XML) is in modules/features/virtualization.nix.

**PLAN (full text delivered in chat, ExitPlanMode DENIED):** Phase 0 host evidence — user plugs SSD, read `/sys/bus/usb/devices/N-N/{idVendor,idProduct,speed,power/control}` (speed 5000/10000 good, 480 USB2 fallback=cable/port, ≤12 bad cable) + `tlp-stat -u` + host dd baseline. Phase 1 VM A/B — current spice redirect vs `virsh attach-device` hostdev (reversible), PowerShell Measure-Command copies; verdict matrix (B fast→redirect overhead, write-only slow→Windows **Quick Removal** policy = write cache off, Device Manager→Policies→Better Performance). Phase 2 fixes — TLP `USB_DENYLIST = "<vid:pid> 14cd:1212"` in hosts/yoga power-tlp.settings (alt global `USB_AUTOSUSPEND=0`), permanent hostdev XML entry for the SSD via virsh edit (manual state, no repo change). Phase 3 — nix fmt + git add + `scripts/test-suite fast` (NO VM battery — TLP change not covered by any VM test), user runs switch (#yoga-niri, sudo agent-blocked), success = ≥100 MB/s hostdev / ≥30 redirect.

**Why:** suspect ranking (autosuspend > negotiation fallback > redirect overhead > guest Quick Removal) drives a measurement-first ladder so fixes are evidence-picked, not shotgun.

**How to apply:** resume = Phase 0 sysfs read the moment the SSD is plugged; related [[virtualization-audit-2026-09-30]], [[lucid-path-wrappers-spice-usb-2026-10-01]], [[vm-nat-firewall-backend-2026-09-30]].
