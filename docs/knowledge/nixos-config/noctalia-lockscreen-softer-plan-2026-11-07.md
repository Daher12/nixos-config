---
name: noctalia-lockscreen-softer-plan-2026-11-07
description: SUPERSEDED (executed same day, see noctalia-lockscreen-soft-round2-2026-11-07) —
  Noctalia lockscreen round 2 plan (softer light mode: shadow off + softer ink + bigger
  clock via box-fit, capsule up + softer glass); new source-verified v5.4.1 facts in file
metadata:
  type: project
---

2026-11-07: follow-up to [[noctalia-lockscreen-sleek-plan-2026-11-06]]. User asked: softer lockscreen (esp. light mode), "hard border around the clock" too much; proposed lighter clock font, no/small border, bigger clock; password prompt higher + more modern. Full plan built, user answered all 3 AskUserQuestion design picks with my recommendations, **ExitPlanMode was DENIED (permission) → NOTHING executed**.

**User decisions (locked):** clock ~90px +60% (box 360×120) / capsule cy 640 / soften glass (0.45→0.35, radius 16→18, input_radius 12→20, input_opacity 0.9).

## The plan (ready to execute)
1. `home/noctalia.nix` clock entry `lockscreen-widget-0000000000000001`: `shadow = false`; add `color = "on_surface_variant"`; add entry-level `box_width = 360.0; box_height = 120.0;`; add `background_padding = 0.0` (invisible plate's default 10px padding eats the box fit); keep cx 768/cy 300, `{:%H:%M}`, bg_opacity 0.0.
2. login box `lockscreen-login-box@eDP-1`: `cy 778→640`, `background_opacity 0.35`, `background_radius 18.0`, `input_radius 20.0`, add `input_opacity = 0.9`.
3. QC: `nix fmt home/noctalia.nix` (explicit path) → `git add` → `nix build .#yoga-niri…home-files` (checkConfig gate) + grep rendered config.toml → `scripts/test-suite fast yoga-niri`; VM battery SKIP (standing precedent).
4. Deployment (order matters): user switch first (also makes staged KillMode=process live) → then strip `[lockscreen_widgets]` from `~/.local/state/noctalia/settings.toml` **while noctalia STOPPED** (state shadows every changed key per-key; resurrection race lore) → start → Mod+L smoke. Gate: `systemctl --user show noctalia -p KillMode` must say `process` before agent stops it; else hand script to user. awk strip pattern: skip from `/^\[lockscreen_widgets\]$/` until next `^\[` header; keep `[lockscreen]` (fingerprint/grace live only there).
5. Memory record + `scripts/export-zcode-memory` after execution.

## New v5.4.1 source facts (SRC=/nix/store/srdcxbw5wryvyl9fvkyfqka57yd5dk5x-source)
- **The "hard clock border" = the hard text shadow**: Shadow role @ 0.6 alpha, offset +1.5/+1.5×scale (desktop_clock_widget.cpp:60-61,655-665). `Label::setShadow(color, x, y)` has NO blur param — on/off only, "small border" inexpressible. Widget cards draw NO border at all; bg_opacity 0 already hides the plate.
- **Bigger clock config-only**: font size hard-fixed 4×body, but `lockscreen_widgets_host.cpp:238,393` calls `widget->setBox(state.boxWidth, state.boxHeight)` and `DesktopWidget::layout` (desktop_widget.cpp:52-66) scales content aspect-preserved to fit an explicit box → box_width/box_height entries scale the clock (~56→~90px at 360×120). Height is the binding constraint (fit = min(w/W, h/H)); box_* are valid ENTRY keys for all lock widgets (login box state proves it). baseScale comes from `[accessibility] uiScale` (default 1.0), NOT monitor scale — eDP-1 is 3072×1920@scale 2 → logical 1536×960.
- **Softer ink**: clock `color` accepts role tokens incl. `on_surface_variant` (palette.h:68 kColorRoleTokens) — theme-following in both modes. Weight stays hard-coded Bold.
- **Login panel border softening**: 1px OutlineVariant border alpha = panelOpacity (lock_surface.cpp:1329) → lowering background_opacity softens border AND fill together.
- Settings registry: clock settings = clock_style/format/center_text/timezone/color/font_family/shadow/circle/show_seconds + common background_color/opacity/radius/**background_padding** (default 10, 0-32) — all checkConfig-valid.

Related: [[noctalia-lockscreen-sleek-plan-2026-11-06]], [[shell-strategy-converge-niri-noctalia-2026-11-07]] (KillMode=process staged there).
