---
name: idle-cpu-round-2026-10-24
description: SUPERSEDED — EXECUTED same day by the same workstream, record in
  [[lucid-idle-round2-126-127-2026-10-24]]; was the plan-mode finding record
  (122-125 deployed but never live; 126/127 approved)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b4aea511-66db-481d-bc67-93a40696dfd7
---

**SUPERSEDED 2026-10-24 (later same day): everything below was EXECUTED — restart done (qs 58→45 ms/s), patches 126/127 authored+QC green+STAGED. Execution record + gotchas: [[lucid-idle-round2-126-127-2026-10-24]].**

User asked 2026-10-24 to cut idle desktop CPU (~180ms/s lucid+Hyprland). Investigation done, plan approved via AskUserQuestion, **ExitPlanMode DENIED → nothing executed**. Extends [[lucid-perf-round-122-125-2026-10-17]].

**Headline finding: the Oct 17 perf round is deployed but NOT LIVE.** Patched files landed in `~/.config/quickshell` Oct 18 23:03 (activation Oct 19 01:31), but quickshell PID 6638 has been up since Oct 18 01:03 and never reloaded (journal: last "Configuration Loaded" Oct 18 01:07) — the "shell outlives deploys" gotcha again. `systemctl --user restart lucid` activates it with zero build. `KillMode=process` → children (bt-agent, dock-launched terminals) survive restart. prefs.json already seeds `ambientMotion: false`.

**Measured** (battery, panel correctly 60Hz post-heal): quickshell ~58 ms/s, Hyprland ~81 ms/s (INFLATED — it was rendering this session's own streaming output; keep the measuring terminal quiet). qs lifetime avg 41ms/s.misc:vfr = "no such option" on 0.55.4 (VFR unconditional → no damage = no render); blur enabled, passes 2, xray false; animations on.

**Remaining 1Hz repainters after round lands:**
- Bar clock colon BLINKS every second by design, even with seconds hidden: `lucidbar/Clock.qml:313` (`opacity: getSeconds()%2===0 || clockShowSeconds ? 1 : 0.35`) + 1s always-on Timer `Clock.qml:92`. (Note: with seconds SHOWN upstream colon is static 1.0 — blink only exists when seconds hidden.)
- `Agenda.qml:275-279` 1s reminder sweep.
Everything else ≥20s polls / condition-gated / open-surface-only (inventory in session, e.g. Cava 100ms liveness but cava never spawns — zero VisualiserWidget instances).

**Approved decisions (user picked both recommendations):**
1. Gate colon blink: patch 126 `126-clock-static-colon` — colon static when `!clockShowSeconds`, Timer minute-aligned (`(60−seconds)×1000`). ⚠️ patch 116 also touches Clock.qml — verify disjoint hunks.
2. Scope: also stage patch 127 `127-agenda-sweep-throttle` (1s→5s). Both QC'd, land with pending switch batch, then restart lucid again + re-measure. NOT the aggressive option (blur-passes-on-battery rejected as unnecessary once damage stops).

**Plan also included:** rm /tmp/.sample{1,2}.txt (measure-agent scratch); re-measure via windowed /proc utime+stime deltas (old /tmp/lucid-perf-dk/measure.sh may be gone); docs sync REPO_OVERVIEW §409 + LUCID_RUNBOOK patch table/count 15→17; **PR1049 pragma patch must now take ≥128** (126/127 taken).

Target: ≲50ms/s combined screen-on at 60Hz (from 139 measured/180 observed); on AC@120Hz residual roughly doubles. Measurement lore: /proc/<pid>/environ of quickshell = EACCES (non-dumpable) — verify patchedness via deployed tree markers + journal reload lines instead.

Stale 1.10.5 lucid store trees exist in /nix/store WITHOUT markers — don't use for verification.
