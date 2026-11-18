---
name: noctalia-theme-m3-content-wallpaper-2026-11-15
description: THEME HARVEST EXECUTED (7ffd2ac pushed) — Noctalia palette =
  M3-content from CURRENT wallpaper, fixed dark, fallback "Tomorrow"; STATE
  STRIP PENDING USER SWITCH; ⚠️ deleting settings.toml while noctalia runs =
  file-watch live-reload to deployed baseline
metadata:
  node_type: memory
  type: project
  originSessionId: sess_364713f2-914e-4aa7-8050-b0e8d602f0dd
---

Theme state (user pick, harvested into nix 2026-11-15, commit `7ffd2ac` pushed): `source = "wallpaper"` + `wallpaper_scheme = "m3-content"` (Material-3 tonal extraction from the CURRENT wallpaper — re-themes on wallpaper change), `mode = "dark"` (sun-schedule auto GONE), fallbacks `community_palette = "Tomorrow"` (a palette NAME) / `builtin = "Nord"`. Supersedes Rosé Pine/faithful/auto (2026-11-06/08). **Everforest DEAD** — never re-propose.

UPDATE 2026-11-17: switch + state strip both DONE (gen 207, Nov 15 00:39 / strip 22:24 — settings.toml now 59 bytes, no theme keys). The `mode = "dark"` half was unintentional loss of auto light/dark; **auto RESTORED** (mode="auto" + shell_mode/sync_color_scheme, fast green, STAGED, pending user switch) — see [[noctalia-auto-mode-restore-2026-11-17]].

Harvest scope (all verified per-key against `noctalia config export merged`): theme ×5 keys, bar.main end+bluetooth+control-center & scale 1.1, shell.animation.speed 0.8 (re-tuned from 1.15), niri type-to-launch OFF, settings_window_translucent, launcher block, panel launcher_position/open_near_click, location.longitude = real meridian 8.524 (was Berlin 13.4), plus previously-undeclared keys: audio.enable_sounds, battery.warning_threshold 15, bluetooth.connection_notifications, weather.refresh_minutes 40, control_center block (avatar/tabs/sidebar/calendar/5 shortcuts), widget.bluetooth hide_when_adapter_off, widget.control-center.glyph "assembly", lockscreen_widgets schema-2 scaffolding (grid + placement/rotation).

**⚠️ STATE STRIP IS PENDING THE USER'S SWITCH — and it MUST stay that way:**
- Deleting `~/.local/state/noctalia/settings.toml` while noctalia runs makes the shell FILE-WATCH reload the CURRENT generation's baseline live (live-observed 2026-11-15 00:18: session flipped to gen-202 Rosé Pine/faithful; restore = copy backup back, auto-reload confirmed 00:20:03).
- Correct sequence: user runs `nus yoga switch` (deploys config.toml WITH the M3 keys; X-Restart-Triggers restart the shell onto it — seamless) → THEN `rm ~/.local/state/noctalia/settings.toml` (backup `settings.toml.bak-2026-11-15` already exists; reload then re-reads the new config.toml = same values = invisible).
- Expected post-strip re-materialization (observed in the accidental live test): ONLY `[idle.behavior.suspend] timeout` (power hooks) + the `[lockscreen_widgets]` editor tree. Everything else staying absent = strip worked.
- `noctalia msg config-get <key>` reads the DISK layered config, NOT the running process's memory — useless for probing in-memory state (it answered gen-202 values during the incident). Journal (`journalctl --user -u noctalia`) is the evidence source for reloads.
- Old lore confirmed still true: strip while shell STOPPED (2026-11-08) — or post-switch (2026-11-15), never pre-switch.
