---
name: c029-guest-ssid-toniebox-objective-2026-11-18
description: New objective 2026-11-18 — guest SSID unification + Toniebox 2.4
  coverage (planned as C029, plan-mode session, ExitPlanMode DENIED so nothing
  authored/executed yet); key reframe "Fritz!Box Arbeit"/"Fritz!Box G" =
  MikroTik SSIDs not hardware
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c949fed6-bb0b-4cdc-aab4-d72f41912c2e
---

**Objective (operator 2026-11-18, plan-mode session):** "drop Fritz!Box Arbeit, make it a 5 GHz extension of Fritz!Box G; evaluate keeping both vs extending G incl. 2.4 GHz" — driver: **Toniebox** (2.4 GHz-only client on guest SSID G since ≥2026-08-24, the repo's only Toniebox mention) has weak G signal.

**Key reframe (repo evidence, C006 2026-08-27):** "FRITZ!Box Arbeit" and "FRITZ!Box G" are **SSIDs, not AVM hardware**. Arbeit = 5 GHz guest SSID on secondary hAP ax2 only (`cap-wifi1-virtual1`, cfg-arbeit-5ghz, sec-guest = same passphrase as G, datapath `arbeitdp` → br-guest on-capsman; client = ThinkPad L14 LAPACH411). G = 2.4 GHz guest SSID on primary only (`wifi-guest-2ghz`). Physical FRITZ!Box (telephony/DECT, hEX ether1, .227) untouched.

**Operator answers 2026-11-18:** objects = SSIDs confirmed; Toniebox room **above secondary hAP ax2, halfway toward cAP ac** (ideal for cap-wifi2 donor); Toniebox stay-on-G vs move-to-main = **evaluate both in assessment**; Arbeit BSS = **rename to "FRITZ!Box G"** (decided).

**Load-bearing technical facts:** Toniebox has no 5 GHz radio → 5 GHz extension cannot serve it; fix = G 2.4 BSS on `cap-wifi2`. cAP ac CANNOT be donor without a guest VLAN (`traffic-processing=on-capsman` unsupported on wifi-qcom-ac; operator ruled out VLANs in C006). Next changeset ID = **C029**; class AGENT_COMPLEX/T3; pattern = C006 (reuse arbeitdp, slave-config on `^hap-ax2-cap` 2.4 GHz rule; rename = one `configuration set` ssid string). Compatible with C028 either order (adds no access-list entries).

**Status:** full lifecycle plan drafted (Phase 0 MCP-availability check — the 2026-11-18 planning session had NO mikrotikmcp tools loaded → probe first, STOP if absent; discovery agent → assessment → operator gate → C029 authoring → independent + second review → seal commit → **hard stop before execution** per operator "mostly automated workflow just before execution, use separate agents for validation"). **ExitPlanMode was DENIED — plan not yet approved, no artifacts written, no device ops.** Resume by re-presenting the plan.

**Why:** future sessions must not treat Arbeit/G as AVM hardware, must probe MCP availability before discovery, and should resume this plan rather than re-derive it.

**How to apply:** on resume, run Phase 0 probe, then execute the 6-phase plan ending before execution; C029 must not run concurrent with C025/C028. See [[open-changesets-portfolio-audit]], [[house-geometry-floor-mapping]].
