---
name: noctalia-lockscreen-round4-weather-v550-2026-11-15
description: EXECUTED+QC green STAGED (switch+strip pending) — Noctalia lock
  round 4 on v5.5.0 zoom@800+edge 0.6+dnd, clock 440x146 (~110px), weather
  widget+service; schema verified in v5.5.0 source; strip script lore in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_883e5fda-292c-44c5-98ab-f46bea1c14d7
---

2026-11-15: user asked for sleeker/modern lock + animations/notifications/weather/suggestions. Decisions (AskUserQuestion): **zoom ~800ms** transition, **weather widget under the clock**, **8.524°E longitude is correct** (GUI beat nix), extras: **v5.4.1→v5.5.0 bump**, **drift harvest**, **bigger clock ~110px**. Notifications ON the lock are NOT expressible upstream (ext-session-lock renders nothing above it; #5264 show_osd still open) — `lockscreen.dnd = true` (new in v5.5.0) is the answer: silent-while-locked, straight to history.

**EXECUTED + QC green + STAGED** (flake.lock, flake.nix, home/noctalia.nix, home/theme.nix). **DEPLOYED 2026-11-15 00:43, live-proven:** user switched (`nus yoga`) → strip fired via `systemd-run --user --collect --unit=noctalia-state-strip` → all green (backup 137 lines → state 3 lines: only config_version=20 + the legitimate suspend-timeout re-materialization). Live: weather.enabled=true, transition=['zoom'], clock box_height=146; session unlocked throughout. User Mod+L smoke pending.

**A parallel session (sess_364713f2) did the 11-15 drift harvest concurrently** (staged: wallpaper/M3-content theme w/ Nord+Tomorrow dormant picks, anim 0.8, launcher/panel keys, bar 1.1 + bluetooth/control-center end widgets, control_center block, location 8.524, widget-editor schema_version=2/grid/placement keys). My round builds on its staging; its knowledge file: docs/knowledge/nixos-config/noctalia-theme-m3-content-wallpaper-2026-11-15.md (Everforest plan DELETED upstream — never re-propose). I added: darkman parity lng in home/theme.nix + fixed its stale "theme auto mode" claim (mode now fixed dark).

**Round-4 changes (home/noctalia.nix):** `[lockscreen]` zoom@800 + `edge_smoothness 0.6` + `dnd true` (comment: transition pool = random pick per event → exactly ONE entry; one transition covers lock AND unlock, per-direction = open PR #5350). Clock box 360×120 → **440×146** (~110px digits). NEW widget `lockscreen-widget-0000000000000002` weather @ cy 435, box 360×60, settings shadow=false / show_forecast=false / background_opacity 0.0 / background_padding 0.0 (plate-less treatment = clock's), in widget_order between clock and login box; ladder clock 227–373 / weather 405–465 / capsule 605–675. NEW `[weather]` service block (enabled/celsius/40/effects — effects is a control-center-tab-only shader, lock widget ignores it). `control_center.circular_avatar` migrated to **shell.circular_avatar** (v5.5.0 upstream move — was the only validate warning, now clean).

**v5.5.0 schema verified IN SOURCE** (nix flake prefetch github:noctalia-dev/noctalia/v5.5.0 → /nix/store/589q0r15...-source): lockscreen dnd+edge_smoothness+zoom in config_schema_desktop.cpp:26/32/35; weather service (enabled/effects/refresh_minutes/unit) in config_schema_system.cpp:36-44; weather desktop-widget type in desktop_widget_factory.cpp:294 accepts color/shadow(**default true!**)/show_forecast/forecast_days + common background_opacity(**default 0.8**)/background_padding(**default 10**); lockscreen host builds `DesktopWidgetFactory(services.runtime)` (lockscreen_widgets_host.cpp:35) so weather works on the lock. **Greeter stays v1.7.0** (latest tag; shell-only bump).

**QC:** checkConfig "✓ Config is valid" (0 warnings, v5.5.0), rendered config.toml grepped key-by-key (zoom/800/0.6/dnd/[weather]/…0002/440×146/location 8.524), `test-suite fast` OK ×3 hosts, `suggest` → no VM covers these files → SKIP battery (precedent).

**Pending deployment (user switch, then agent strip):** 1) user: `nus yoga` while UNLOCKED; 2) agent: `systemd-run --user --collect --unit=noctalia-state-strip /tmp/noctalia-state-strip.sh` (prepared: absolute shebang + PATH, cp backup → **~/.local/state/noctalia/settings.toml.bak-lockscreen-r4-20261115** (persisted dir — /tmp backups die with tmpfs, the 11-15 one is already gone), stop → `: >` state → start). Strip is REQUIRED not hygiene: live state's [lockscreen_widgets] (old order, clock 360×120) shadows the new lock per-key. Header comment in noctalia.nix now points at the durable backup path.

Smoke checklist: Mod+L zoom-in ~800ms → ~110px clock → weather line → capsule; weather tab in control center @ 8.524°E; `noctalia msg config-get weather.enabled`; DND-while-locked (no sounds).

Related: [[noctalia-theme-m3-content-wallpaper-2026-11-15]] (knowledge mirror), [[noctalia-lockscreen-soft-round2-2026-11-07]] (box-fit + state-race lore), [[noctalia-config-export-energy-2026-11-08]] (config-set/strip lore).
