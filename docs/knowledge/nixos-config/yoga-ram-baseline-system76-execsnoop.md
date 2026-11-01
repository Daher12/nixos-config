---
name: yoga-ram-baseline-system76-execsnoop
description: yoga idle RAM ~4GB is normal; the odd-looking 200MB python
  execsnoop process is system76-scheduler's foreground-boost watcher, not a
  rogue consumer
metadata:
  node_type: memory
  type: project
  originSessionId: sess_d5d69365-bf2e-48cf-a2c0-1bcd99c142cc
---

RAM diagnosis 2026-10-14 (user reported "3.6GB while doing nothing"): verdict NORMAL — 10Gi of 15Gi available, 0B swap. Baseline consumers: ZCode Electron session ~1.9GB (biggest chunk, varies with sessions), quickshell/lucid ~430MB fresh, Hyprland ~240MB, service tail ~450MB (tailscaled, fwupd, libvirtd, portals, Xwayland).

The one surprising resident: a ~200MB `python .../bcc/tools/execsnoop` running as `nobody` under `system76-scheduler.service`. It is SPAWNED BY the system76-scheduler daemon (same user, same start time) — it is the process-exec watcher behind `processScheduler.foregroundBoost.enable = true` in `profiles/laptop.nix` (`services.system76-scheduler` block, lines ~25-34, also `useStockConfig` + `cfsProfiles`). Only lever to reclaim it = disabling foregroundBoost (not recommended for 200MB on 15GB).

**Why:** this process pattern-matches "suspicious spyware-looking python running as nobody" and will recur in future memory/ps audits.
**How to apply:** attribute it to system76-scheduler immediately; don't re-derive. `free -h` "available" is the number that matters, not "benutzt/used" (~6GB page cache is reclaimable). See [[yoga-battery-drain-2026-09-27]] for ZCode as the known cost center.
