---
name: everforest-palette-plan-2026-11-10
description: Everforest palette swap for yoga-niri — PLAN ready, ExitPlanMode
  DENIED, NOTHING executed; palette research facts + full wiring plan
metadata:
  node_type: memory
  type: project
  originSessionId: session_10591e375844de8ba5d1e5fc504fc871
---

User wants a new palette for niri: Rose Pine dark good / light bad, Nord light "barely good enough"; asked for between-RP-and-Nord, light mode NOT pastel, colloid-nord vibe. Picked **Everforest (medium)** via AskUserQuestion 2026-11-10. PLAN fully formed, ExitPlanMode denied — nothing executed.

**Research facts:**
- Colloid GTK ships official Everforest variant; nixpkgs `colloid-gtk-theme` tweak enum includes `everforest` (also nord/dracula/gruvbox/catppuccin). Current pin: `home/theme.nix:18` `tweaks = [ "nord" ]` — but niri host GTK = adw-gtk3 (noctalia branch), Colloid only on lucid/GNOME hosts.
- Noctalia community palettes (noctalia.dev/palettes, fetched at runtime, cached in persisted state — "Rose Pine Alt" precedent): Everforest, Everforest Alt, Everforest Material, Flexoki, Tokyo Night Moon/Storm, Kanagawa Paper/Kasumi/Dragon, Nord Aurora, Catppuccin, Gruvbox Material, etc. Not embedded in the binary.
- Everforest hexes verified from sainnhe/everforest palette.md: dark bg0 #2D353B fg #D3C6AA red #E67E80 orange #E69875 yellow #DBBC7F green #A7C080 aqua #83C092 blue #7FBBB3 purple #D699B6; light bg0 #FDF6E3 fg #5C6A72 red #F85552 … blue #3A94C5. Tokyo Night Day light: bg #e1e2e7 fg #3760bf blue #2e7de9 red #f52a65 (runner-up). Catppuccin Latte = the pastel anti-pick.
- btop 1.4.8 SHIPS built-in everforest themes (everforest-dark-medium.theme etc.) → vendored rose-pine btop theme (terminal.nix ~64-166) can be DELETED.
- foot 1.27: colors-dark/colors-light sections + initial-color-theme; runtime switch = color-theme-switch-* keybinds or SIGUSR1/2 — foot does NOT watch the color-scheme portal → terminal stays dark-only (deliberate status quo).
- theme.nix: darkman DISABLED on noctalia host — Noctalia itself drives light/dark; switch-theme script sets gsettings color-scheme. No theme-event hook found in Noctalia binary strings (18 hook kinds, none theme).

**Plan (for executor):** noctalia.nix ~196 community_palette → "Everforest"; terminal.nix rename rosePineTerminal→everforestTerminal, foot colors-dark → Everforest (16-color values from official kitty port, never from memory), fzf branch swap, DELETE vendored btop theme → color_theme "everforest-dark-medium" (else "nord"); niri.nix:96 ring `#c4a7e799`→`#7fbbb399`; REPO_OVERVIEW sync. Untouched: lucid hosts, GTK/adw-gtk3, bat (Nord). QC: nix fmt explicit files, test-suite fast incl. yoga-niri attr, home-files probe. Switch user-run + restart foot-server & Noctalia. See [[shell-strategy-converge-niri-noctalia-2026-11-07]], [[niri-rice-polish-2026-11-07]].
