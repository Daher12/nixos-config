---
name: multimonitor-niri-dp2-2026-11-19
description: Multi-monitor niri support EXECUTED — monitor binds + DP-2 4K
  declarative above panel; outputKdl now renders ALL desktop.monitors entries
  with logical-pixel positions
metadata:
  node_type: memory
  type: project
  originSessionId: sess_810e57f3-980e-4fbf-b2a2-c85ea356b658
---

EXECUTED 2026-11-19, `test-suite fast` green, UNCOMMITTED (like the rest of the working tree — audit-fixes/update-sweep changes from 11-18 share it). Deployed by the next yoga switch.

- **User question origin**: "no monitor settings in Noctalia" — correct, Noctalia is only the shell; monitor arrangement is niri (config.kdl + `niri msg`). No GUI exists.
- **home/niri.nix rewritten**: head-only `outputKdl` → `monitorKdl isPanel: m:` rendered via `lib.imap0` over ALL `desktop.monitors` entries. Per entry: `mode` (@Hz stripped → resolution-only; `"preferred"` drops the line), `scale` (dropped when auto), `position` (NEW — regex `(-?[0-9]+)x(-?[0-9]+)` + throw guards; negatives survive the match, no fromJSON needed). VRR `on-demand=false` stays **panel-only** (isPanel flag); externals keep session-scoped `niri msg output DP-2 vrr on`.
- **Nix `''`-string trap**: literal `      }` placed AFTER interpolations in a source line is mid-line content — indentation stripping never touches it → emitted `}` carried 6 stray spaces. Fix: `...${vrrLine}}` (last prop line ends in `\n`, brace rides on it at col 0).
- **Binds added** (both were free): `Mod+Shift+<arrow>` = focus-monitor-*, `Mod+Shift+Ctrl+<arrow>` = move-column-to-monitor-*. `move-window-to-monitor-*` / `move-workspace-to-monitor-*` left unbound (commented alternative).
- **hosts/yoga/home.nix**: DP-2 (Beihai M27-4K-144-C) 3840x2160@144 **scale 1.5, position `-512x-1440`** = above panel, centered (panel logical 1536×960 @ 0,0; DP-2 logical 2560×1440; x = 768 − 2560/2 = −512, y = −1440). First cut was scale 2 / `-192x-1080` — user flipped to 1.5 same day ("scale back to 1,5"). Panel-first order is load-bearing (battery-refresh reads head-with-@Hz; panel also feeds the GNOME `-x/-y` placement, battery-refresh.nix:184).
- **Geometry gotcha**: niri positions are LOGICAL pixels — scale 2 halves both monitors (panel 1536×960, 4K 1920×1080).
- Docs synced: battery-refresh.nix position option (no longer "GNOME backend only"), REPO_OVERVIEW rows desktop-niri/battery-refresh/niri.nix.
- VM battery: SKIPPED per user decision 2026-11-19 (build-time `niri validate` proves syntax; no physical DP-2 in VMs).
