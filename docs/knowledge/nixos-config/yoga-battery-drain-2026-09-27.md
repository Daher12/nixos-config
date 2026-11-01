---
name: yoga-battery-drain-2026-09-27
description: Battery drain analysis 2026-09-27 — evening 73%→15% fully explained
  by active use (ZCode Electron ~70% core = cost center); battery 86% health
  (60.13/70 Wh, 264 cycles); upower .dat files are ground truth (format
  ts/value/state, value = $2)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_32c8af46-d133-4204-add7-d543db01d680
---

2026-09-27 ~23:15: user reported 60%→16% drain "after a long zcode session". Analysis verdict: NO rogue drain, NO config problem — full accounting from upower history + journal. Electron AI sessions are simply expensive; lever if user wants headroom = close the Electron app when reading (~5–8 W).

Timeline (all 2026-09-27): night session 00:00–01:00 (97%→~76%, 9–17 W, bursts 20–26 W) → clean shutdown 01:00, machine OFF 01:00→20:58 (zero drain, no suspend) → evening boot 20:58 at 73% → active 13–16 W → heavy burst 21:52–22:08 (20–25 W sustained) → quiet 22:08–22:48 (steady 9–10 W) → reboot 22:50 → ZCode session 22:52–23:15 (27%→15%, 13–25 W, 17.6 W at analysis time). Evening ≈ 25%/h ≈ 15 W average over 2¼ h.

Durable hardware baseline: L21D4PE0 (Sunwoda), ENERGY_FULL 60.13 Wh vs 70 design = **86% health, 264 cycles** (2026-09-27) — each % ≈ 0.6 Wh, so equal workload reads as more %/h than design implies; part of the "feels fast" perception.

Efficiency knobs verified ALL engaged that evening: TLP active, powersave governor, EPP balance_power, battery-refresh (60Hz-on-battery) running, brightness 28%. Idle floor screen-on 9–10 W (vs 7–9 W during the 09-26 night session) — normal for this 2880×1800 AMD panel.

Data-source lore (reusable): `/var/lib/upower/history-{charge,rate,voltage}-L21D4PE0-70-3199.dat` = per-minute ground truth, world-readable even in the [[zcode-shell-sandbox-etc]] sandbox. Format is `timestamp value state` — the VALUE is field $2 (charge file = percent, rate file = watts); field $3 is the state string, NOT percentage (misparsed it twice before noticing; raw file uses comma decimals). Boot gaps in these files = machine off/suspended; pair with `journalctl --list-boots` to disambiguate.

Open questions asked, unanswered: (1) user said "started at 60%" but data shows 73% at the 20:58 boot, crossed 60% only at 21:29 — per [[ask-dont-infer-system-state]] asked instead of assuming; (2) 22:08–22:48 sat at 9–10 W for 30 min with NO DPMS/suspend despite the [[yoga-energy-idle-2026-09-22]] DMS idle policy (3 min DPMS on battery) — consistent with user being present, but if they were away the idle chain didn't fire and needs a look.

Related: [[yoga-power-audit-2026-09-19]].
