---
name: niri-focus-follows-mouse-2026-11-15
description: focus-follows-mouse flag added to niri input block in home/niri.nix
  — EXECUTED+fast-gate green STAGED 2026-11-15, lands with the pending gen-202
  switch
metadata:
  node_type: memory
  type: project
  originSessionId: sess_6c5750a3-808d-4287-b5cd-70378d26c6fb
---

User asked "set mouse hover = active window into nix" — added `focus-follows-mouse` (bare flag) to the `input { }` block of the generated KDL in `home/niri.nix`, no `max-scroll-amount` cap (full behavior; default 10% limit removed). `warp-mouse-to-focus` deliberately NOT set (focus changes never move the cursor).

**Why:** niri schema fact — `focus-follows-mouse` is a flag NODE (`focus-follows-mouse` / `focus-follows-mouse max-scroll-amount="10%"`), NOT an `enable true/false` subsection; off by default; off omitted. Separate option `warp-mouse-to-focus` moves the cursor on keyboard focus.

**How to apply:** Status: edit done, `nix fmt` + `git add home/niri.nix` staged, `scripts/test-suite fast yoga` green (dry-build re-ran the `niri validate` gate → syntax proven for niri 26.04). Applies live at the pending `nus yoga switch` ([[noctalia-lockscreen-round4-weather-v550-2026-11-15]] shares that switch) — niri hot-reloads config.kdl on HM activation, no logout needed. Related: [[niri-dwt-palm-rejection-2026-11-11]] (same input block).
