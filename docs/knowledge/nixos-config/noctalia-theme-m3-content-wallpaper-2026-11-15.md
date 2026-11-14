---
name: noctalia-theme-m3-content-wallpaper-2026-11-15
description: THEME STATE (user 2026-11-15) — Noctalia palette = M3-content
  extracted from the CURRENT wallpaper (dynamic); fallback community palette =
  "Tomorrow"; Everforest plan DEAD; declarative config still pins Rose Pine Alt
  + faithful (state layer wins)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_364713f2-914e-4aa7-8050-b0e8d602f0dd
---

User statement 2026-11-15, verified against the live state layer (`~/.local/state/noctalia/settings.toml`):

```toml
[theme]
community_palette = "Tomorrow"
source = "wallpaper"
wallpaper_scheme = "m3-content"
```

- **Active:** Material-3 "content" quantization from the CURRENT wallpaper — the palette follows wallpaper changes (dynamic, not a fixed scheme).
- **Fallback:** community palette "Tomorrow" (a palette NAME, not a date) if wallpaper sourcing is ever turned off.
- **Everforest is DEAD** — the 2026-11-10 plan memory was deleted; never re-propose it.
- **Drift:** declarative `home/noctalia.nix` still pins `community_palette = "Rose Pine Alt"` + `wallpaper_scheme = "faithful"` (2026-11-06/11-08 era). The persisted state layer wins per-key, so the pending `nus yoga switch` does NOT disturb this theme. If the user ever wants nix to be the layer of record again, harvest these three keys into home/noctalia.nix (pattern: the 2026-11-08 state-harvest round, `noctalia config export merged`).
- Reusable facts folded in from the deleted everforest record: Noctalia community palettes are RUNTIME-FETCHED (that is how "Tomorrow" is available without a nix change); a Colloid `everforest` tweak exists in the theme package if ever needed; btop ≥1.4.8 ships common themes builtin; foot stays dark-only by design.
