---
name: noctalia-lockscreen-soft-round2-2026-11-07
description: EXECUTED+QC green STAGED on niri-testing — softer Noctalia
  lockscreen rounds 2+3 (shadow off, box-fit clock ~90px, capsule cy 640 pill
  input; round 3: clock on_surface, panel surface@0.30 frosted, input 0.55);
  source lore (no-blur shadow, setBox box-fit, padding insets fit) in file
metadata:
  node_type: memory
  type: project
  originSessionId: session_e200f959a626fa3d7b36d5a6249488d4
---

2026-11-07: user asked for a softer lockscreen "at least in light mode — the hard border around the clock is a little too much"; wanted lighter clock font, small/no border, bigger clock, password prompt higher + more modern. All three taste questions answered with my recommendations: clock +60% (~90px), cy 640, soften glass. **EXECUTED, QC green, STAGED (nothing committed). VM battery SKIPPED** (config-values only; standing precedent, no VM boots a graphical lock).

**Diagnosis (source-verified, SRC=/nix/store/srdcxbw5wryvyl9fvkyfqka57yd5dk5x-source, v5.4.1):** the "hard border around the clock" is NOT a card border — widget cards draw no border and the clock plate was already invisible (background_opacity 0.0). It's the digital clock's **hard text shadow**: Label::setShadow(colorSpecFromRole(Shadow, 0.6), +1.5, +1.5) — **no blur parameter exists** (label.h setShadow = color+offsetX+offsetY only), so in light mode the dark offset edge behind digits reads as a border. Only on/off expressible.

## New source lore (verified this round)
- **Bigger clock WITHOUT C++ patch**: `lockscreen_widgets_host.cpp:238,393` calls `widget->setBox(state.boxWidth, state.boxHeight)` for EVERY lock widget (not just login_box), and `DesktopWidget::layout` scales content aspect-preserved to FILL an explicit box (contentScaleForBox, clamp 0.05–20). Font stays hard-fixed 4x body (desktop_clock_widget.cpp:21) but the box-fit multiplies it. Height is the binding constraint: box 360x120 → ~90px digits. `scale` still NOT a setting (validator warns) — box_* entry-level keys are the size control.
- **background_padding insets the box fit**: applyBackground/contentScaleForBox subtract 2*pad from the box before fitting (default 10px). Zero it when boxing a bare widget, or the invisible plate steals 20px of fit area.
- **Clock color accepts role tokens**: palette.h kColorRoleTokens — "on_surface_variant" valid, follows light/dark (config_types.cpp parseColorSpecString: hex first, then role token). Font WEIGHT stays hard-coded Bold (desktop_clock_widget.cpp:219) — "lighter font" is only expressible as lighter INK.
- **Login panel border softening**: lock_surface.cpp:1329 `setBorder(colorForRole(OutlineVariant, loginStyle.panelOpacity), Style::borderWidth)` — the hard-coded 1px border's ALPHA = background_opacity, so 0.45→0.35 softens fill AND border together.
- **input_opacity** is a real login_box setting (default 1.0, 0–1) alongside input_radius (0–32); pill = 20.

## Executed diffs (home/noctalia.nix, [lockscreen_widgets])
- Clock `lockscreen-widget-0000000000000001`: shadow false, color "on_surface_variant", NEW entry-level box_width 360.0 / box_height 120.0, settings += background_padding 0.0; cx 768/cy 300 kept.
- Login box `lockscreen-login-box@eDP-1`: cy 778→**640**, background_opacity 0.45→**0.35**, background_radius 16→**18**, input_radius 12→**20**, NEW input_opacity **0.9**; compact/400/0 box kept.
- Block-header comment updated (clock no longer "position/style only" — box-fit is the size control).

## QC (all green)
nix fmt (explicit path) → git add → `nix build .#nixosConfigurations.yoga-niri…home-files` → checkConfig "✓ Config is valid" (proves box_*/color/background_padding/input_opacity schema-valid) → grep rendered config.toml value-by-value (bar.main shadow=true at line 16 is the DESKTOP bar, unrelated) → `scripts/test-suite fast yoga-niri` OK.

## Round 3 (2026-11-07 afternoon) — EXECUTED+QC green+LIVE STAGED
User feedback on round 2 live look: clock "a little too muted — could be a tad brighter"; password prompt+box "too opaque or colorful — should be frosted or muted or both (preferred)". Edits in home/noctalia.nix: clock `color` on_surface_variant → **on_surface** (brightest theme-following ink; role tokens carry NO alpha knob so there is no in-between that follows the theme — hex would drop theme-following); login box adds `background_color = "surface"` (most neutral role — surface_container read tinted/colorful), `background_opacity 0.35 → 0.30`, `input_opacity 0.9 → 0.55` (pill read solid). QC: checkConfig ✓, rendered config grepped (on_surface / surface / 0.3 / 0.55), `test-suite fast yoga-niri` OK. VM skip (precedent).
**Deployed (fix-lockscreen-r3 service):** KillMode gate green → strip rerun clean (0 hits, benign re-normalization again — state now mirrors round-3: on_surface, surface@0.30, input 0.55/20). User Mod+L smoke pending at record-write time.

## ✅ Deployment EXECUTED 2026-11-07 14:43 (live-proven)
User switched → KillMode=process verified live → strip run detached via `systemd-run --user --collect --unit=…`: stop → awk strip → start, all green (0 lockscreen_widgets hits, noctalia active). **Restarted shell re-normalized `[lockscreen_widgets]` back INTO state from the merged config** — resurrected section carries the NEW values (cy 640, 0.35/18, input 20/0.9, clock 360×120, shadow false, on_surface_variant). So in the correct order (strip while stopped) the resurrection is BENIGN — state becomes a mirror of the new baseline; the dangerous variant was only the old-model flush from a RUNNING shell. Backup: /tmp/settings.toml.bak-lockscreen-r2-20261107-144315. [lockscreen] (fingerprint/grace) preserved.

**⚠️ NEW TRAP — systemd-run transient services on NixOS:** the user manager's PATH does NOT resolve bare `bash` (tries /usr/bin/bash → ENOENT, service fails at EXEC before doing anything). Absolute shebang + `PATH=/run/current-system/sw/bin` at script top required; first attempt failed harmlessly (noctalia never stopped).

**User smoke test:** Mod+L — expect ~90px soft-gray clock (no hard edge in light mode), capsule at two-thirds with pill input; dark-mode check after sunset.

Related: [[noctalia-lockscreen-sleek-plan-2026-11-06]] (round 1 + state-race lore), [[noctalia-niri-swap-exec-2026-11-06]], [[shell-strategy-converge-niri-noctalia-2026-11-07]] (KillMode=process staged).
