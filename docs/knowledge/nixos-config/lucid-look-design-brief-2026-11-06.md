---
name: lucid-look-design-brief-2026-11-06
description: Lucid desktop "frosted lofi" design spec + grounded look facts
  (blur recipe, rounding 16, Google Sans Flex, grayscale palette) for recreating
  the style in Noctalia/DMS
metadata:
  node_type: memory
  type: reference
  originSessionId: session_fc35404dffa676a480ada73be8ab5370
---

2026-11-06: User asked for a description of the lucid desktop style/structure/looks to build a design prompt (likely to recreate the look under Noctalia on niri-testing, see [[noctalia-niri-swap-exec-2026-11-06]]). Lucid is based on a pastel lofi-anime screenshot (floating capsules top bar, calendar+weather cards left, big-clock+media cards right, pill dock bottom-center, full-width bottom audio visualizer) "but with a more frosted look".

Grounded look facts (from home/hyprland.nix + home/lucid-themes/grayscale):
- Frost recipe (Hyprland-side, lucid slider only sets translucency + blur regions): blur size 10, passes 2, vibrancy 0.2, noise 0.04, ignore_opacity=true; inactive_opacity 0.96; shadow range 24.
- rounding = 16 is LOAD-BEARING: matches Lucid's Material 3 corner radius so windows and shell popouts share one radius; gaps_in 8 / gaps_out 12.
- UI font = Google Sans Flex (3-axis, shipped from lucid input via xdg.dataFile fonts/lucid + fc-cache).
- Actual palette is the GRAYSCALE Material pair (quickshell.json: primary #c6c6c6 on surfaces #1f1f1f→#3d3d3d, light variant in quickshell-light.json) — NOT the screenshot's pastel cyan/pink; static-theme import chosen over matugen accent.
- Borders are a static Nord pair (active 7d7eaa, inactive 4c566a); matugen colors only shell+GTK, never the compositor.
- Motion: Material 3 curves (decel/accel/std), windows slide, layers fade.

The full copy-pasteable English design brief (frosted-lofi structure/mood/shape/type/color/motion) was delivered in chat 2026-11-06; if needed again, regenerate from these facts. Palette swap note: brief describes grayscale reality with wallpaper tints through the frost; for a colorful mock replace COLOR paragraph with pastel cyan/pink/lavender derived from wallpaper.
