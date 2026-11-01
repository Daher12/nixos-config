---
name: hyprland-gestures-altbinds-2026-09-27
description: GNOME-style 3-finger gestures + ALT+N move-to-workspace binds
  implemented 2026-09-27 in home/hyprland.nix — staged uncommitted on
  lucid-testing; Hyprland 0.55 Lua gesture API + chord-ownership facts
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ee83bfa8-5218-45bc-a715-859190ff0d7c
---

2026-09-27, user request ("GNOME-like gestures" + "move active window with ALT+<n>"): IMPLEMENTED + STAGED in `home/hyprland.nix` (flake-index staged, NOT committed, NOT switched). Takes effect only at next rebuild switch + `hyprctl reload` — Hyprland does not watch the config file.

What was added (lands in generated `~/.config/hypr/hyprland.lua`):
- `hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })` — 0.55 native 1:1 workspace swipe (replaces old hyprlang `gestures { workspace_swipe }`; workspaces follow fingers, GNOME-like by default, no invert knob needed)
- `hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("qs ipc call workspaces toggle") end })` — 3-finger up = lucid workspace overview (the SUPER+TAB surface) as the Activities-overview stand-in
- `for i = 1, 10 do hl.bind("ALT + " .. i % 10, hl.dsp.window.move({ workspace = i })) end` — ALT+1..0 (10→key 0) = movetoworkspace, same dispatcher as lucid json's ws-move (SUPER+SHIFT+N), so behavior matches existing muscle memory

**Why this shape:** 0.55 built-in gestures have no native pinch/overview — horizontal-workspace + exec-lambda-up is the full GNOME-feel coverage.

**GOTCHA (user-caught 2026-09-27, fixed):** `hl.gesture` `action` accepts a **string** (builtin action name: workspace/close/float/special/fullscreen/move/resize/cursor_zoom) or a **plain Lua function/lambda** — NOT the dispatcher object `hl.dsp.exec_cmd(...)` returns (that form is only valid as the second arg of `hl.bind`). Exec-on-gesture must be `action = function() hl.exec_cmd("cmd") end` (verbatim wiki example). Gesture fields: fingers [2-9], direction (swipe/horizontal/vertical/left/right/up/down/pinch/pinchin/pinchout), optional mods/scale/disable_inhibit; `action = "unset"` removes a gesture. Authoritative doc: hyprland-wiki `content/configuring/core/binds/gestures.md` (the live wiki page fetch truncates — fetch the raw markdown from GitHub).

**How to apply (reusable facts):**
- Hyprland 0.55 Lua API reference ships IN-PACKAGE: `/nix/store/<hyprland>/share/hypr/hyprland.lua` — grep it before web-searching; wiki's hyprlang pages describe 0.54 (old syntax)
- Keybind chord ownership: static binds in `home/hyprland.nix` vs runtime `~/.config/lucid/keybinds.json` (owns SUPER+N focus / SUPER+SHIFT+N move, mouse, XF86, tap-Super). Live json is ground truth — checked before adding chords: bare ALT was unused (only SUPER+ALT+S), `grp:alt_shift_toggle` (ALT+SHIFT layout switch) is a different chord, no conflict
- QC trick for compositor-config edits: build home-files tree, grep the generated lua, syntax-check with `$(nix eval --raw nixpkgs#luajit.outPath)/bin/luajit -bl <file>` (catches a reload-killing syntax error before the user switches), then dry-build yoga
- REPO_OVERVIEW.md keybinds paragraph (~line 381) extended in the same change + restaged — keep in sync if binds change again

Related: [[yoga-energy-idle-2026-09-22]] (0.55 Lua parser quirks — `hyprctl keyword` no-ops, use `hyprctl eval`/reload), [[lucid-integration-plan]]
