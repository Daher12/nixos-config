---
name: yoga-slowboot-gc-catchup-2026-10-27
description: yoga "slow boot" 2026-10-27 = nix-gc Persistent timer catch-up (not
  a fault); gen 190/kernel 7.2.11 first boot = all 2026-10-24 staged work now
  LIVE; lucid-auto-mode 34.5s gsettings retry wart, user declined fix
metadata:
  node_type: memory
  type: project
  originSessionId: sess_949d046e-a2d6-4282-a52d-dc5a9d0e9971
---

Boot 2026-10-27 23:47 (only boot that day; laptop was powered off Oct 25 01:33 → Oct 27 23:47). Diagnosis: NOTHING broken.

- **Slow feel = `nix-gc.timer` catch-up**: weekly Mon 00:00 with `Persistent=yes`; missed Monday run fired 3s after userspace start, ran ~94s, deleted 23,566 paths / 20.6 GiB incl. 20 old generations, competing with login I/O. systemd-analyze showed 1min 58s total but graphical.target @8.8s, greetd @~18s, session @~32s — desktop normal. Expect the same on any first boot after a weekend offline. User declined softening (ionice etc.).
- **Generation 190 (`26.05.20261021.da6dc0e`) + kernel 7.2.11-zen1 went live with this boot** — created by switch Oct 25 01:02, first booted Oct 27. So ALL the 2026-10-24 "pending switch" work ([[lucid-wifi-129-2026-10-24]], [[lucid-fingerprint-off-128-2026-10-24]], [[lucid-idle-round2-126-127-2026-10-24]], [[cleanup-round-2026-10-24]], [[update-sweep-2026-10-24]], [[battery-refresh-resume-heal-2026-10-24]], [[yoga-hibernate-status]]) is now live (fresh boot also restarts lucid, satisfying the "lucid restart" caveats — not yet journal-verified though).
- **lucid-auto-mode 34.5s wart**: root-caused same evening; user initially declined a fix, then reversed — plan in [[lucid-auto-mode-gsettings-fix-plan-2026-10-27]], EXECUTED+QC green STAGED 2026-10-28, see [[lucid-automode-gsettings-env-2026-10-28]] (pending switch+verify).
- **Diagnostics lore**: no "Startup finished" journal lines exist (`systemd.log_level=warning` on cmdline suppresses PID 1 info); compare boots via initrd→real-root journald handoff timestamps instead. `journalctl --grep` is broken on this build ("Das Argument ist ungültig"). Boot-time gap analysis via `journalctl -b -o short-monotonic` + python delta script works well. `nix-optimise.timer` fires 00:03 after any >1wk gap — harmless disk burst.
- Usual per-boot noise (don't chase): Lenovo ACPI BIOS errors, `pci 0000:00:01.1 retraining failed`, bluez BAP/ISO-socket lines, dbus-broker duplicate-name spam, `home-dk-Öffentlich.mount` invalid unit name.
