---
name: lucid-brightness-steps-plan-2026-11-01
description: SUPERSEDED (executed: brightness-keys-e4-2026-11-01 — live
  keybinds.json edit, 10% linear steps); diagnosis preserved: keys walk
  brightnessctl -e4 quartic curve, OSD/sliders linear; patch-130 plan
  REJECTED by user ("no more patches to maintain")
metadata:
  node_type: memory
  type: project
  originSessionId: session_9004ed79a4629029ff8087062b845152
---

Diagnosed 2026-11-01 (plan mode; ExitPlanMode permission DENIED — plan delivered in chat, NOTHING executed). Supersedes nothing; new area.

**Symptom:** brightness keys granular (~2%) at low brightness, 20-30% jumps per press near max.

**Root cause (evidence-backed, both Explore agents + live probes):**
- Keys (`xf86-bright-up/down` in `~/.config/lucid/keybinds.json:451,463`; F5/F6 variants disabled) run `brightnessctl -e4 -n2 set 5%±` — +5 points on a QUARTIC curve `(raw/max)^0.25`. Near max one press = +18.5 linear points; from >81.45% curved one press saturates to 100%; low end ≈ 2 points. `repeating: true` can stack two steps per OSD refresh → "20-30%".
- Bar/OSD/sliders/idle-dim are all LINEAR percent (`lucidbar/System.qml:122,657`, `lucidosd/Osd.qml:26,359`, `Idle.qml:168` — `brightnessctl set N%` no -e, `Math.round(raw/max*100)`); slider wheel = 5 linear points, no stepSize. Display space ≠ key-step space = the bug.
- NO repo patch touches brightness (19 patches grepped clean); upstream default in `support/hypr/keybinds.json` lines 42-43/52-53. No lucid prefs key for brightness step size. Lumen/Lens (v1.20.5.5) are file manager / image viewer — unrelated to brightness.
- Hardware: single `amdgpu_bl1`, max_brightness 65535, `scale: non-linear`, `actual_brightness` (6477) ≠ `brightness` (4096) — amdgpu DM applies its own conversion, a third curve layer (informational, untouched). brightnessctl 0.5 `-e` = exponent, `-n2` = min-value floor 2 raw.

**Plan v1 (REJECTED by user):** patch 130 drop -e4 from the seed — user said "i honestly dont want another patch to maintain". (Also note: parallel session's patchset-maintenance plan keeps 130 RESERVED; do not spend 130 here.)

**Plan v2 — NO-PATCH live edit (ExitPlanMode DENIED again, NOTHING executed):** one-time edit of `~/.config/lucid/keybinds.json` only, either via Lucid Settings → Keybinds → Media keys (delete `-e4 ` from Brightness up/down cmds; save applies LIVE via hyprctl reload) or agent jq `walk(if type == "object" and (.cmd? | type == "string") then .cmd |= sub(" -e4"; "") else . end)` + `hyprctl reload` + read `$XDG_RUNTIME_DIR/lucid-keybinds-status.json`. Result: `brightnessctl -n2 set 5%±` = exactly ±5 linear points per press at every level. No repo changes, no patch, no restart.

**Edit durability (verified in source, all three layers):**
- Repo lucidSync rsync `--exclude`s keybinds.json; its jq seed runs only `if [ ! -s ... ]`; all repo migrations guard on exact old cmd values and none touch brightness cmds (the 2026-11-01 Lumen→nautilus revert migration ran same day and left them alone).
- Upstream seed only-if-absent; both upstream migrations (nautilus→lumen, float-lua) guard on exact old default; Settings editor (Keybinds.qml) writes file + `hyprctl reload` after 150ms, watchChanges re-parses external jq edits into the UI without clobbering.
- binds.lua reads keybinds.json ONCE per Hyprland config load → jq edit takes effect on `hyprctl reload`; `systemctl --user restart lucid` does NOT rebind (only restarts the QML UI); missing/unparsable file = 8-bind EMERGENCY set (no brightness binds).

**Onset archaeology (user hint "started 1-2 weeks ago" — lucid provably did NOT change):** `-e4 -n2` cmds byte-identical at EVERY pinned rev (09820bb/e662954/8bc3266/4b8fc9a/2945eab), original since d958241 2026-09-01 (hardcoded binds.lua) / 341f484 2026-09-17 (keybinds.json); live since first lucid deploy 20f4bb0 2026-09-23. OSD/bar linear-percent display also byte-identical since v0.91 beta 04aac70 2026-08-23 (pickaxe-proven; v1.20 rewrite changed visuals only). Pre-lucid stepping was DMS `dms ipc call brightness increment 5`. Remaining onset candidates: kernel/nixpkgs bump in the Oct 24-31 window (amdgpu non-linear backlight mapping is kernel-dependent) or simply running brightness higher lately (top-end saturation only shows >81% curved). Future feel-changes after kernel bumps = the driver layer, not lucid — don't chase the shell.

**Follow-up if flat 5% too coarse at low end:** user self-services `-e2` (or step size) in the same Settings page — no agent needed.

**Lore:** brightnessctl relative linear math `new = ((curr/max)+0.05)*max` = exactly +5 linear points; `-e4 set 50%` → raw 4096 of 65535 (matches the live brightness at diagnosis time — keys had walked it there). `hyprsunset` was running during diagnosis — tints perceived steps, judge by OSD numbers.
