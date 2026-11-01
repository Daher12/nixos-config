---
name: house-geometry-floor-mapping
description: AP physical placement and first-floor design intent
  (operator-stated 2026-09-13) — resolves the 5x-flagged "OG = 2.4-only"
  topology question
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e089daea-9cea-44a4-a870-73fa762d43b8
---

Operator-stated 2026-09-13 (recorded in `inventory/current-state.yaml` §physical_placement):

- **hap-ax2 (primary)**: ground floor, one end of the house.
- **hap-ax2-cap (satellite)**: ground floor, opposite end.
- **hap-ac-cap**: staircase, central, on the last stair before the first floor.
- **First-floor design intent**: 2.4 GHz shines through the walls to the first floor; the cAP ac (cap-wifi3, ch6, 18 dBm) is the intended first-floor donor. First-floor 5 GHz = cap-wifi4 (12 dBm small cell) only.

**Why it matters:**
- Closes the topology flag raised in 5 consecutive periodic audits (2026-09-13 00:22→15:02). Live all-both-bands state is deliberate; no "OG = 2.4-only" defect exists.
- **Operator decision 2026-09-13: cap-wifi3 STAYS at 18 dBm** (15 dBm trim declined for comfort/margin). The weak-landing magnet pattern ([band-steering-crossover-pincer]) therefore remains as-is; no tx-power change planned on this radio.
- First-floor RSSI walk was PERFORMED 2026-09-13 but results were not filed in evidence — request numbers if a first-floor decision ever needs data.
- **cap-wifi4 12→8 dBm: DECLINED for now** (operator 2026-09-13: no new changeset — parked). Earlier same-day "operator open" signal superseded.
- KSB 2462 co-channel is strongest at the house center (−62 at staircase vs −69 primary / −79 satellite) → channel plan 1/6/11 confirmed correct (operator concurs: all channels contested); cap-wifi3/ch6 is the right first-floor server.
