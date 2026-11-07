---
name: stack-comparison-research-2026-11-07
description: Research report (delivered in chat 2026-11-07) —
  responsiveness/resource comparison niri vs Hyprland, Noctalia vs DMS, lucid
  baseline; key discovery = pinned Noctalia v5.4.1 is native C++/GLES (no
  Qt/quickshell)
metadata:
  node_type: memory
  type: project
  originSessionId: session_f6fca00573ebca27de359502aa30b6f8
---

Research request (chat only, NOTHING executed): compare responsiveness + resource usage of niri vs Hyprland and Noctalia vs DMS, integrating lucid data. Context = choosing between the three yoga stacks: Hyprland+lucid (live), Hyprland+DMS (dux-shell branch), niri+Noctalia (niri-testing branch).

**Load-bearing discovery:** the pinned noctalia (github:noctalia-dev/noctalia v5.4.1) is NOT quickshell — since v5.0.1 (Sept 2026) it is a ground-up **C++/OpenGL-ES shell, no Qt dependency** (11.9k stars). Consequences: no QML engine → no lucid-style 2.84s qsintercept startup tax; upstream claims ~6× less memory than its own quickshell v4 (~300MB/monitor → ~50MB-class). DMS/dux-shell = quickshell+Go = **same engine class as lucid** → inherits quickshell's 427MB RSS / structural QML startup tax (PR #1049 disk-cache would give it the same −40MB/0.77s-warm win lucid abandoned).

**Measured baselines (only first-party data, lucid+Hyprland):** Hyprland 0.55.4 ~240MB RSS, 9.4–10% core idle (80–92 ms/s, inflated by rendering the measuring terminal); quickshell/lucid 427MB RSS, 58→44–47 ms/s after patches 122–125, ≲25 ms/s expected once 126/127 go live; combined "~180 ms/s idle" symptom; residual roughly DOUBLES on AC@120Hz — so idle-CPU comparisons across sessions are apples-to-oranges unless both run 120Hz.

**niri vs Hyprland verdict:** near parity at compositor level; niri GitHub issue #1522 reports +0.1–0.3% idle CPU for niri (cursor movement ~doubles CPU) — the "niri is lighter" narrative is not backed by numbers. niri's real advantages here: session architecture (no uwsm needed), `niri validate` build gate (config fails the BUILD vs Hyprland 0.55.4's silent `hyprctl keyword` no-ops), and niri 26.04 blur economics: **xray blur = wallpaper computed once and cached (cheap); xray false = per-frame mid-render readback (expensive)** — the kitty frost rule uses `xray false`, i.e. the expensive path, acceptable for one window. Community benchmarks: equal frame pacing/1% lows; anecdotes slightly favor niri smoothness, Hyprland multi-monitor.

**Noctalia vs DMS verdict:** resources favor Noctalia (different engine class, see above); animation richness favors DMS (expressive buckets, 250ms base ×0.2–×2; user recalls DMS "smoother than lucid"; Noctalia has only a global speed knob, easing hardcoded). DMS ships German upstream (retires the lucid 318-rule dictionary); Noctalia needs zero patches so far but custom look = C++ patch layer (dot-morph already declined on that basis). Noctalia watch-items: lockscreen system-graphs widget had a 15→75% CPU spike (upstream-patched); community "Performance Plus" profile exists.

**live confound:** niri session stuck 60Hz BOTH states ([[battery-refresh-niri-broken-2026-11-06]]) — every niri responsiveness comparison is handicapped until that 6-step fix runs; any fair shell/compositor measurement needs both sessions at 120Hz on AC.

**Proposed measurement protocol (not yet run):** fix niri mode → per-session `pidstat` ms/s for compositor + shell processes (user-manager unit names make this trivial), RSS, login→bar time; ~10 min per session. Nobody has first-party numbers for niri, Noctalia, or DMS on this machine.
