---
name: niri-multi-monitor-plan-2026-11-18
description: PLAN ready (ExitPlanMode DENIED, NOTHING executed) — niri monitor
  keybinds + declarative DP-2 external above panel; desktop.monitors head-only
  trap lore
metadata:
  node_type: memory
  type: project
  originSessionId: sess_810e57f3-980e-4fbf-b2a2-c85ea356b658
---

User asked "how to manage multiple monitors in niri? no setting in Noctalia" 2026-11-18. Answer: Noctalia is just the shell; output management is niri's KDL config + `niri msg output` — no GUI exists. Full plan was finalized (user answered AskUserQuestion: keybinds + declarative external "above the laptop panel centered", connector DP-2), then ExitPlanMode DENIED — nothing executed. Plan is self-contained in chat, key values:

- **Hardware**: panel eDP-1 3072×1920@scale2 → logical 1536×960 @ (0,0). External DP-2 (Beihai "M27-4K-144-C") 3840×2160@144. Chosen: scale 2 → logical 1920×1080 → position `x=-192 y=-1080` (centered above; midpoint 768). Alt scale 1.5 → `-512x-1440`.
- **Keybinds to add** in home/niri.nix binds block (both combos verified collision-free): `Mod+Shift+<arrows>` = focus-monitor-*, `Mod+Shift+Ctrl+<arrows>` = move-column-to-monitor-*; commented move-window/move-workspace-to-monitor variants.
- **Code change**: home/niri.nix outputKdl currently uses `builtins.head monitors` only (line ~17) and never emits `position` — map over ALL desktop.monitors entries, emit position (parse "WxH", fromJSON handles negatives), scale (≠"auto"), mode (@Hz-stripped as today). Panel stays entry #1 (battery-refresh reads head).

**Lore:**
- Custom `binds {}` block replaces niri's ENTIRE default bind set — monitor binds were never ported, count was 0.
- niri directional binds (Mod+dir / Mod+Ctrl+dir) already cross monitor edges spatially; dedicated *-monitor-* actions force one-monitor jumps.
- niri workspaces are PER-MONITOR (Mod+N targets active monitor). Unconfigured outputs auto-on at preferred mode, placed right of everything (name-sorted). Positions are LOGICAL px.
- niri matches outputs by connector name OR "manufacturer, model, serial" string — connector changes if cable moves ports.
- `niri msg output <name> position/mode/scale/off` for live tweaks (battery-refresh already uses this IPC).
- Doc sync owed: battery-refresh.nix option doc says position "GNOME backend only" (stale after change); REPO_OVERVIEW ~162/166.
- User first pasted eDP-1's descriptive line by mistake, then corrected with the DP-2 line — descriptive match string "Beihai Century Joint Innovation Technology Co.,Ltd M27-4K-144-C 0000000000000".

Related: [[niri-rice-polish-2026-11-07]], [[battery-refresh-niri-backend-2026-11-07]], [[noctalia-auto-mode-restore-2026-11-17]]
