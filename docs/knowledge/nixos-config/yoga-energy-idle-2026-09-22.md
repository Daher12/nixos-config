---
name: yoga-energy-idle-2026-09-22
description: 60Hz switch was silently dead (hyprctl keyword no-op under 0.55 Lua
  parser) — fixed + idle policy added; staged on dms-caelestia-look, needs user
  switch + one manual service start
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ea2bc9d9-7a09-42a7-b962-e6205089d2ca
---

2026-09-22 energy round (extends [[yoga-power-audit-2026-09-19]]): the 60 Hz battery switch was NOT working — Hyprland 0.55's Lua config parser refuses `hyprctl keyword monitor` ("non-legacy parsers") while exiting 0, so the daemon "succeeded" silently (same for the lid-close panel binds). Fixes COMMITTED 4b2f965 on dms-caelestia-look (2026-09-23, NOT pushed): battery-refresh.nix → systemd user service both sessions, apply = `hyprctl eval 'hl.monitor{...}'` checking literal `ok` output (eval also exits 0 on error), failed applies retry each poll; hyprland.nix lid binds → eval `disabled=true` on close, `hyprctl reload` on open (eval disabled=false does NOT re-enable, only reload does — verified live 0.55.4); DMS idle seeds in desktop-hyprland.nix (DPMS/lock/suspend = 3/5/15 min bat, 10/15/60 AC, behavior=Suspend); REPO_OVERVIEW gotcha added.

**Pending user action:** `nus` switch activates seeds (dms restarts) but per the known gotcha a NEWLY-wanted user unit is not auto-started mid-session → run `systemctl --user start battery-refresh` once (or relogin); new lid binds need one `hyprctl reload`/relogin. Runtime verifications pending: lid bind fires, DMS idle timers fire (keys verified against running shell's QML source), gmc-vs-mutter still unverified. Old broken daemon killed; panel left at 60 Hz live (machine on battery). User decisions 2026-09-22: idle suspend 15/60, lid-on-AC stays clamshell, conservation mode declined. Full lore in REPO_OVERVIEW § gotchas + power tuning; see [[caelestia-integration]] for DMS settings mechanics.
