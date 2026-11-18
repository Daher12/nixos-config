---
name: noctalia-auto-theme-restore-2026-11-17
description: SUPERSEDED — EXECUTED same day by the parallel session, see
  [[noctalia-auto-mode-restore-2026-11-17]]; plan record (root cause +
  v5.5.0 semantics + state-layer trap lore still accurate)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_700ecb31-4057-4038-b4aa-eb68922628c2
---

User reported "automated light/dark mode not working" 2026-11-17. Root cause: NOT a bug — commit `7ffd2ac` (Nov 15 theme harvest, see [[noctalia-theme-m3-content-wallpaper-2026-11-15]]) baked the GUI's then-current fixed-dark state (`theme.mode = "dark"`, was `"auto"` since fee3af7 Nov 7) into `home/noctalia.nix`; deployed with gen 207 on Nov 15 00:39. darkman is deliberately gated off on the noctalia attr (home/theme.nix `!desktop.noctalia.enable`), so no other mechanism exists. REPO_OVERVIEW.md lines ~165/167 carried stale claims ("shell owns day/night GTK switching", Rosé Pine templates) — doc rot inviting confusion.

**Machine state correction:** the old "gen 202 since Nov 8, switch pending" lore is STALE — yoga switched Nov 15 00:39 to gen 207 (nightlight/state strip also done: settings.toml = 59 bytes, only config_version + idle.behavior.suspend, i.e. NO theme keys in state layer → nix config governs).

**Noctalia v5.5.0 theme semantics (schema-verified in locked flake input `src/config/schema/config_schema_theme.cpp` + docs/user/theming/index.mdx):**
- `mode = "auto"` flips light/dark on the `[location]` sunrise/sunset schedule (same machinery as night light; nightlight need NOT be enabled; unresolvable schedule → light fallback). Coords corrected to real meridian 8.524 on Nov 15.
- `shell_mode` = follow|dark|light|auto (default follow) — Noctalia's own surfaces incl. wallpaper directory selection.
- `sync_color_scheme` (default true) — writes `org.gnome.desktop.interface color-scheme` so browsers/Electron/Qt/libadwaita follow WITHOUT any template.
- `source = "wallpaper"` works with auto: mode selects the palette VARIANT (light/dark M3 from same wallpaper).
- `wallpaper.directory_light` / `directory_dark` = day/night wallpaper pair (exists, unused).
- `terminal_colors` = palette|standard for wallpaper-generated ANSI colors.

**Approved plan (NOT executed — ExitPlanMode denied):** user chose "restore what I had" (shell + modern apps flip; GTK3 adw-gtk3-dark pin + terminal stay dark) + keep wallpaper M3 palette. Plan: `home/noctalia.nix` mode→"auto", explicit `shell_mode = "follow"` + `sync_color_scheme = true` with comments, fix the "fixed dark" comment block, sync REPO_OVERVIEW (+grep README); `nix fmt`, `git add`, `test-suite fast yoga`; VMs recommended SKIP (home-layer toml value change); user runs `nus yoga switch`.

UPDATE 2026-11-17: **SUPERSEDED — executed by the parallel session moments later, byte-for-byte the same plan**, see [[noctalia-auto-mode-restore-2026-11-17]] (fast tier green, STAGED, pending user switch).

**⚠️ How it broke, keep-it-working lore:** GUI/IPC theme-mode actions (theme-mode-toggle, control-center shortcut, theme bar widget) write `theme.mode` into the state layer and override nix `auto` — that's how fixed dark crept in. Fix = remove the `theme.mode` line from `~/.local/state/noctalia/settings.toml` (shell stopped or post-switch, per strip lore). Verify post-switch: `dconf read /org/gnome/desktop/interface/color-scheme` (prefer-dark evening / prefer-light after sunrise; sunset ≈16:25 local mid-Nov at 52.52/8.524); `journalctl --user -u noctalia` shows mode transitions.
