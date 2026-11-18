---
name: noctalia-lockscreen-round4-plan-2026-11-15
description: PLAN ONLY (ExitPlanMode denied ×2, NOTHING executed) — sleek
  lockscreen round 4 (zoom 800ms + weather widget under clock + ~110px clock +
  Noctalia v5.5.0 bump + state strip); full locked decisions +
  v5.5.0/notifications facts in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_883e5fda-292c-44c5-98ab-f46bea1c14d7
---

2026-11-15: user asked for sleeker/modern lockscreen + animations/notifications/weather. All questions answered; final plan ready but ExitPlanMode **denied twice** (permission denied, no feedback). NOTHING executed.

**User decisions (locked):**
- Transition `["zoom"]` @ 800ms + `edge_smoothness = 0.6` (same effect lock+unlock; per-direction = open PR #5350)
- Weather widget UNDER the clock (new `lockscreen-widget-0000000000000002`, cx 768 / cy 435, box 360×60, plate-less `background_opacity 0.0` + `background_padding 0.0`; ladder clock 227–373 / weather 405–465 / capsule 605–675)
- Location truth = **8.52°E** (GUI right, nix Berlin wrong) — longitude already harvested by parallel session; **darkman `home/theme.nix:212` lng 13.40 → 8.52 still OPEN**
- Extras: **Noctalia v5.4.1 → v5.5.0** (adds `crt` transition + `[lockscreen] dnd`; if checkConfig rejects `dnd`, drop it), **bigger clock** 360×120 → 440×146 (~110px digits), harvest drift (already done by parallel session), `[lockscreen] dnd = true` as the notifications answer
- Weather service: `enabled = true; unit = "celsius"; effects = true;` (refresh_minutes 40 already in nix)

**Facts (upstream-researched 2026-11-15):**
- **Notifications ON lockscreen are IMPOSSIBLE upstream** (ext-session-lock renders nothing above it, no config key in v5.4.1 or main; they land in 3h history + control center). Landed post-v5.4.1: PR #5162 `[lockscreen] dnd` (in v5.5.0); `lockscreen.show_osd` = open PR #5264. Live-preview transitions via `noctalia msg config-set lockscreen.transition '["zoom"]'` + Mod+L.
- v5.4.1 transition pool: fade/wipe/disc/stripes/zoom/honeycomb/vortex/pixel/diamond/golden/melt (v5.5.0 adds crt); duration 100–30000ms. Repo = github.com/noctalia-dev/noctalia, docs docs.noctalia.dev, per-tag example.toml is authoritative (docs pages can disagree — `unit = "celsius"` not "metric").
- Parallel session (2026-11-15, landed with retirement push per theme record) already harvested the FULL drift into nix: wallpaper/m3-content theme (Nord + Tomorrow = dormant fallbacks), animation 0.8, launcher/panel keys, bar 1.1 + bluetooth/control-center end widgets, control_center block, location 8.524, widget-editor metadata (schema_version/grid/placement_*) recorded verbatim so a strip is safe.
- **State strip has NOT run** (settings.toml full, mtime 11-15 00:03; the /tmp backup referenced in the noctalia.nix header is GONE — tmpfs wipe). Strip is REQUIRED for this round: live state's `[lockscreen_widgets]` (order without weather widget, clock 360×120) shadows new lock config per-key. Strip while stopped, backup into the PERSISTED state dir this time (config glob only reads ~/.config/noctalia/*.toml, a state-dir .bak is inert). Suspend timeout is the one key that legitimately re-materializes in state (power hooks config-set it).

**Why:** state layer wins per-key over nix; every lockscreen round needs the stop→strip→start cycle (detached systemd-run unit, absolute shebang + PATH — [[noctalia-lockscreen-sleek-plan-2026-11-06]] lore).

**How to apply:** remaining work = flake bump v5.5.0, lockscreen block (zoom/800/0.6/dnd), clock 440×146, weather widget + order, weather service enabled, theme.nix darkman lng, QC (real home-files build for checkConfig — dry-build does NOT run it), then user switch + detached strip.

Related: [[noctalia-theme-m3-content-wallpaper-2026-11-15]], [[noctalia-lockscreen-soft-round2-2026-11-07]], [[noctalia-config-export-energy-2026-11-08]].
