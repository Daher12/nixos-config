---
name: storage-audit-2026-10-06
description: T0 storage/leftover audit 2026-10-06 (all 4 devices) — no storage
  pressure fleet-wide; hap-ax2 carries ~75 stale backup/export files (~2.9 MB,
  July-setup→C18 era) + orphan script cap-monitor (run-count 0); cAP ac still
  has C027's wireless→memory rule *5 live (C028 candidate) and only 64 KB / 16
  MB flash free (no room for new .backup — pre-exec exports must go straight to
  repo); hex-poe poe-out→memory rule is intentional F13 forensics, keep
metadata:
  node_type: memory
  type: project
  originSessionId: sess_9b9263f6-bd5f-4af7-a760-48fe871cc4c3
---

Read-only (T0) sweep 2026-10-06 across all 4 devices (get_system_status, list_files, list_scripts, list_scheduled_jobs, list_log_rules/actions). Zero writes, no stop conditions. Trigger: operator request "check storage situation, logs, old backups, pending scripts, leftovers".

**Per-device findings:**
- **hap-ax2 (primary)**: 92/128 MB flash, 680 MB/1 GB RAM free; **78 files ≈ 2.9 MB** = every pre-change backup/.rsc since the July setup (pre-pppoe, pre-guest, baseline, C3/C5/C6/C7/C11/C13 v1–v5/C14–C18 eras) + throwaway test backups from the 2026-08-24 MCP-access work (rand-user-test, new-group-test, custom-group-test, group-name-test, rest-probe, rest-addr-probe, ssh-console-test). Not a capacity problem (~2 % of flash) — a hygiene problem; most are superseded by repo `evidence/before/` copies. **Orphan script `cap-monitor`** (owner admin, full policy, run-count=0, nothing references it — no scheduler exists on the box; from the 08-20 CAP-stability era, body logs CAP registration state). Log rules = 4 defaults only → C027 removal live-reconfirmed.
- **hap-ax2-cap**: clean — 11 files (Aug/Sep pre-change exports only), no scripts/jobs, default log rules only; 94.6 MB free.
- **hap-ac-cap (cAP ac)**: only 4 files (auto-before-reset + pub/skins dirs) but **64 KB free of 16 MB NAND** — normal for the full 7.23.5 package set, yet **no room to write a new .backup**: any future pre-exec export for this device must go straight to the repo via export/SFTP. 17 MB/128 MB RAM free (13 %), CPU 23 %; lifetime write-sect-total 445 583 = highest in fleet (hAPs ~53–58 k; oldest device, memory-only log rules do not write flash). **Leftover rule *5 `topics=wireless → memory` still live** — the identical flooding rule C027 removed from the primary; C027 was primary-scoped, so this is a scoping gap that drowns the CAP's local 1000-line ring → **C028 candidate**.
- **hex-poe**: 3.1/16 MB free, 4 files; rule *5 `poe-out → memory` is **intentional** (F13 link-event counter-forensics baseline, [[f13-uplink-rootcause-status]]) — do NOT flag or clean as leftover.

**Fleet-wide:** no .npk/upgrade leftovers, no disk log files, no scheduled jobs on any device, all 7.23.5 long-term with matching RouterBOARD firmware, uptimes 3w3d–3w5d (no surprise reboots), cAP ac retries needed (two 30 s MCP timeouts on first pass, succeeded on retry).

**Offered, not drafted:** one AGENT_EASY housekeeping changeset "storage hygiene v1" — delete stale/test backup+rsc files and `cap-monitor` on hap-ax2, remove the cAP ac `wireless→memory` rule; three persistent targets → normal review with per-operation validation. Awaiting operator go-ahead (2026-10-06).

Related: [[open-changesets-portfolio-audit]], [[wifi-incident-2026-10-05]], [[f13-uplink-rootcause-status]].
