---
name: win11-vm-double-cursor-plan-2026-11-11
description: windows11 VM double mouse cursor — diagnosis (viogpudo client-mouse
  cursor-hide bug, NOT GPU accel) + fix plan (libvirt <mouse mode='server'/>),
  PLAN ready ExitPlanMode DENIED nothing executed
metadata:
  node_type: memory
  type: project
  originSessionId: session_ec43a4d870c86aa8648d49506570bf7f
---

User reported double cursor in the windows11 VM (2026-11-11), suspected GPU acceleration. **Diagnosis: not accel** — domain runs `<video><model type='virtio'/>` with `gl=no` (viogpudo has no virgl anyway). Root cause = the 2026-09-30 QXL→virtio video switch (needed for sharp 3072×1920; QXL vgamem 16MB caps ~2560×1600): with QXL the cursor was one hardware sprite; on virtio-gpu SPICE uses client-mouse mode where virt-viewer draws its own cursor AND Windows draws one — the Spice agent should suppress one, but viogpudo ignores Windows' hide-cursor request (known driver bug, UTM issue #4896). The Sept audit's "mouse slightly sluggish" note was likely this same artifact. User confirms guest virtio-win tools are ALREADY latest → driver update path dead.

**PLAN (ExitPlanMode DENIED, NOTHING executed):**
1. Host: `virsh dumpxml` baseline (confirm spicevmc channel + tablet + virtio video), snapshot `pre-cursor-fix`.
2. Windows (user does manually — their choice): services.msc check/restart Spice Agent (vdservice); if dead service was it → done.
3. Core fix (host, no Windows changes): add `<mouse mode='server'/>` inside `<graphics type='spice'>` in the domain XML (libvirt ≥1.2 native, no qemu:commandline needed) → forces server mouse: virt-viewer stops drawing local cursor, single guest cursor; spicevmc channel KEPT so auto-resize/clipboard/USB redirect survive; absolute positioning stays via USB tablet. Takes effect on next VM start.
4. Verify: single cursor, native res, auto-resize, clipboard, iPhone USB redirect. Rollback = remove element; trivial.

Rejected/weak: nefarius/vd_agent (mirror of abandoned win32 agent; does NOT claim double-cursor fix, validated vs QXL only); QXL revert (loses native res); VNC (loses clipboard/auto-resize/USB redirect); RDP viewing = bigger fallback if server-mode cursor feels laggy.

Related: [[windows11-vm-ssh-mcp-itunes-2026-09-30]] (video flip), [[vm-usb-ssd-slow-plan-2026-11-11]] (same VM). Lore: plan mode blocked virsh/nix eval/ssh as non-readonly — diagnosis relied on knowledge docs; domain XML is imperative libvirt state (no repo file).
