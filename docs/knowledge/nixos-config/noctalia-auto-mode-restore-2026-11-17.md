---
name: noctalia-auto-mode-restore-2026-11-17
description: AUTO LIGHT/DARK RESTORED 2026-11-17 — mode=auto + shell_mode=follow
  + sync_color_scheme=true in home/noctalia.nix, fast green STAGED (pending user
  switch); root cause = 7ffd2ac harvest baked GUI's parked fixed-dark; v5.5.0
  auto-mode semantics + GUI-toggle state-layer trap in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_700ecb31-4057-4038-b4aa-eb68922628c2
---

User reported "automated light/dark not working" 2026-11-17. Root cause: NOT a bug — commit `7ffd2ac` (2026-11-15 theme harvest) baked the GUI's then-parked **fixed dark** state into nix; deployed with **gen 207 on Nov 15 00:39**. Pre-Nov-15 the shell ran `theme.mode = "auto"` (sun schedule) since the Noctalia swap (Nov 7). Machine state correction: gen 207 is current (the long-standing "gen 202 pending" index claim was stale — gens 203–207 landed Nov 9–15), and the 11-15 state strip is DONE (`~/.local/state/noctalia/settings.toml` = 59 bytes, only `config_version` + `[idle.behavior.suspend] timeout` — no theme keys).

Fix EXECUTED 2026-11-17 (fast tier green, STAGED, uncommitted — lands with user's next `nus yoga switch`):
- `home/noctalia.nix` `[theme]`: `mode = "dark"` → `"auto"`, added explicit `shell_mode = "follow"` + `sync_color_scheme = true`; wallpaper-M3 palette (`source = "wallpaper"` + `m3-content`) kept — user chose "restore what I had" (shell + modern apps flip; GTK3/terminal stay pinned dark) with wallpaper palette for the light face. Comment block + `REPO_OVERVIEW.md` theme.nix/noctalia.nix rows de-staled (README had no stale claims).
- darkman gate stays off (`home/theme.nix`); no template changes (btop/gtk3/gtk4 ids still dormant).

**v5.5.0 auto-mode semantics** (source-verified: `src/config/schema/config_schema_theme.cpp` + `docs/user/theming/index.mdx` in the flake input):
- `mode = "auto"` flips dark/light on the `[location]` sunrise/sunset schedule — the SAME machinery as night light (no need for night light to be enabled); custom `sunset`/`sunrise` times via `location.custom_schedule = true`; unresolved schedule defaults to the LIGHT face.
- `shell_mode`: `follow` (default) | `dark` | `light` | `auto` — pins the SHELL surfaces independently of `mode`; templates + color-scheme NEVER follow shell_mode.
- `sync_color_scheme = true` (default) writes `org.gnome.desktop.interface color-scheme` on every mode flip → browsers/Electron/Qt/libadwaita follow through the portal WITHOUT any template.
- `source = "wallpaper"` works with auto: mode selects the palette VARIANT, so the day face = light M3 extraction of the same wallpaper.
- Bonus keys seen in the schema: `wallpaper.directory_light` / `directory_dark` = day/night wallpaper PAIR option (not used).

**⚠️ Recurrence trap:** GUI/IPC theme-mode actions (`theme-mode-toggle`, `theme-mode-set`, control-center shortcut, theme-mode bar widget) write `theme.mode` into the state-layer `settings.toml`, which WINS over nix per-key — exactly how fixed dark crept in. If auto ever "stops working" again: check that file for a `theme.mode` key and delete the key to return to the nix baseline (file-watch live-reload applies it instantly).

Post-switch verification levers: `dconf read /org/gnome/desktop/interface/color-scheme` (prefer-dark evenings / prefer-light days), `journalctl --user -u noctalia` for mode transitions. VM battery skipped — home-layer TOML value change, no VM test imports Noctalia theming. Related: [[noctalia-theme-m3-content-wallpaper-2026-11-15]] (palette record; its "auto GONE" claim superseded by this).
