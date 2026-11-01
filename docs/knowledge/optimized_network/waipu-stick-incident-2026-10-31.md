---
name: waipu-stick-incident-2026-10-31
description: waipu stick (88:42:D0:0D:14:47) slow-WiFi incident 2026-10-31 — ALL
  on 2.4 GHz at good signal (user thought "WiFi 6"); 5 drops with ~33 s
  client-side recovery gaps = stick-side instability; 5 GHz risk separate (weak
  cells + post-C026 −78 exit never evicts); operator chose 2.4 GHz band-pin →
  C028 SEALED (sig 68e43e…8f28, commit 5699fa9) + first review PASS + second
  review 2026-10-31 REVIEW_PASS — NOT executed, awaits T3 per-op approvals
metadata:
  node_type: memory
  type: project
  originSessionId: sess_55a927bd-08ef-4ec6-bd8a-c2306086fc17
---

Operator report 2026-10-31 evening: Android TV stick (waipu-tv-Stick-G2, 88:42:D0:0D:14:47, DHCP .245 dynamic, stable global MAC) "sometimes really slow on WiFi 6, restarting WiFi helps; today it restarted with WiFi 4 and switched back to 6, then fine."

**Router log truth (T0, prefix-filtered ring):** stick used **zero 5 GHz in the whole 24 h window**. 11:04 connected wifi2 (2.4 ch11); 19:30:53 connection-lost at −67 → 19:31:01 fresh assoc on cap-wifi3 (2.4 ch6) + DHCP de/reassign (= the restart, "WiFi 4"); 20:56 cap-wifi3→wifi2; then **5 more connection-lost drops (21:09, 21:11, 21:27, 21:30, 21:35) all at −64…−69 with ~33 s constant reconnect gaps** (= client retry timer); offline 21:35 (TV off). Android shows "Wi-Fi 6" badge for the ax SSID even when linked 2.4 n — user's "switched back to 6" was UI, not association.

**Two-problem verdict:** (1) today's failures = **stick-side instability** (same Sept device-side stall pattern; suspects: firmware, TV-USB power) — band-independent, pin won't fix it; (2) real separate risk = weak-5 camping: wifi1 historically −68…−71, cap-wifi4 −82 at stick position, and post-C026 exit −78/45 s never evicts such camps → the historical "slow WiFi 6" episodes. 2.4 cells serve −62…−69 (three cells ch1/6/11).

**Operator decision (AskUserQuestion 10-31): "Pin to 2.4 GHz"** — C028 (change-028-waipu-stick-2g-pin-v1): 3 C025-style access-list reject rules on wifi1/cap-wifi1/cap-wifi4 for the MAC (comments c028-waipu-block-5g-*), 2.4 untouched (no cAP-ac SPOF — rejected the cap-wifi3-only variant because of cAP ac's Oct 8 kernel failure). AGENT_COMPLEX/T3 confirmed by both reviews. **Plan executed same evening (hard stop per phase):** incident evidence `evidence/verification/2026-10-31-waipu-stick-incident-analysis.md` (commit 1257e9b; corrections vs my live read: 28 h ring, 17 entries — cause NOT determinable, NOT attributable to hEX PoE/C026/prior changesets; storm client E2:E5:A3:6B:66:01 = household iPhone; 30 s reject-scan-reject stop rule is C025 §Final validation item 3); C026 final validation **AMBIGUOUS** (no trust record) + C027 final **PASS** + trust record `04804c72…7b10` (commit 6b388d0); canonical state update + YAML repair (82a1a92). **C028 sealed:** commit 5699fa9 (sig `68e43efa…f8f28` recomputed MATCH), hashes finalised 88281e4 (changeset a42e5554…b72b, review 2e6e1465…fd5c). **Second independent review 2026-10-31 (~23:00): REVIEW_PASS** — `reviews/change-028-waipu-stick-2g-pin-v1-second-review-2026-10-31.md` (uncommitted); all hashes/sig MATCH from committed blobs; docs semantics confirmed (reject = association-time only, never kills an existing session); live: 6 radios on-plan, 4/4 healthy, stick offline since 21:35:40, lease .245 bound; first-review C1 discharged, C2–C4 remain standing execution-time gates; new findings 2R-F1..F7 all note/minor (F1: access-list emptiness not re-verifiable without run_command — covered by execution precheck; F2: reject-loop watch advisory). **Next: T3 per-op execution approvals (operator).** Stick lease could later be made static (C024-style, make-static broken → lease-menu workaround).

**Bonus observations from same reads:** the all-night roaming storm (E2:E5:A3:6B:66:01, hundreds of roams 22:30→09:27 across all six cells, incl. 5 GHz) = the **iPhone** (.250 per MAC map in [[wifi-incident-2026-10-05]]) — weak-cell churn persists post-C026 (10-30/31 night); yoga was stable on cap-wifi2 2.4 at −49 with ~260/287 Mbps. Ring held ≥24 h (~794 wireless entries/24 h) = C027 gate-2 input.

Related: [[wifi-incident-2026-10-05]], [[band-steering-crossover-pincer]], [[open-changesets-portfolio-audit]], [[house-geometry-floor-mapping]], [[mikrotik-mcp-diagnostic-techniques]].
