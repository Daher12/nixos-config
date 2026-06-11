# GPU Monitoring: `intel-gpu-metrics`

## Overview

The `intel-gpu-metrics` service collects Intel GPU utilization on
**nix-media** (N100 Alder Lake) and exposes them as Prometheus
node-exporter textfile metrics for Grafana dashboards.

Defined in `hosts/nix-media/monitoring.nix` as a systemd oneshot
service running every 60s via a timer.

## How It Works

```
intel_gpu_top -l -s 1000 -n 6
    │         │      │
    │         │      └── 5 samples (n-1), exit automatically
    │         └───────── 1000ms interval between samples
    └─────────────────── plain-text output (not TUI)
```

The tool runs for ~5 seconds collecting 5 snapshots of GPU engine
busyness. The output is piped through awk which extracts the `%`
column for three physical engine classes and averages them.

### Output format (`-l` plain text)

```
 Freq MHz      IRQ RC6     Power W             RCS             BCS             VCS            VECS
 req  act       /s   %   gpu   pkg       %  se  wa       %  se  wa       %  se  wa       %  se  wa
 534  611     2291   0  1.11 11.99   58.71   0   0    0.00   0   0   98.06   0   0   32.88   0   0
```

| Column | Field | Engine | Purpose |
|--------|-------|--------|---------|
| `$7`   | RCS % | Render/3D | 3D/compute |
| `$13`  | VCS % | Video | Encode/decode |
| `$16`  | VECS %| VideoEnhance | Scaling, denoise |

### Generated metrics

```
intel_gpu_engine_busy_percent{engine="render"} 0.00
intel_gpu_engine_busy_percent{engine="video"} 0.00
intel_gpu_engine_busy_percent{engine="videoenhance"} 0.00
intel_gpu_busy_percent 0.00
intel_gpu_build_info{version="2.3"} 1
```

Written to `/var/lib/prometheus-node-exporter/intel_gpu.prom` and
scraped by the Prometheus node-exporter textfile collector.

## 26.05 Upgrade Failure

### Root cause

`intel-gpu-tools` was updated from 2.2 to 2.3 in NixOS 26.05. The
new version changed the default output mode from plain-text to
interactive TUI. Three things broke simultaneously:

1. **No machine-readable output** — the TUI mode writes ncurses
   escape sequences or hangs when piped. Without a `-l`, `-c`, or
   `-J` flag, `intel_gpu_top` produces nothing parsable.

2. **`set -e` propagated timeout** — the script had `set -euo pipefail`.
   `intel_gpu_top`in TUI mode runs until killed. The `timeout 4s`
   wrapper kills it after 4 seconds and exits with code 124 (SIGALRM).
   `set -e` promotes this to a script failure, so the output file
   is never written.

3. **Old parser expected engine class names** — the pre-upgrade awk
   parser used keyword matching (`/Render\/3D/`, `/^Video:/`,
   `/VideoEnhance/`) which worked with version 2.2's class-based
   output. Version 2.3 with `-l` outputs physical engine columns
   (`RCS`, `VCS`, `VECS`) in a positional table.

### Why not JSON

The initial fix attempt used `-J` (JSON output) with `jq` parsing.
This was rejected because earlier experience showed `jq` produced
inconsistent results on this hardware (likely due to the N100's
intermittent GPU waking from RC6 states causing empty or partial
JSON frames). The original author had already switched from JSON
to awk for reliability.

### Fix applied

| Change | Reason |
|--------|--------|
| `set -euo pipefail` → `set -uo pipefail` | Timeout (exit 124) no longer kills the script |
| Added `-l` flag | Forces plain-text output in v2.3 |
| Added `-n 6` | Bounded iteration (5 samples), tool exits cleanly |
| `timeout 4s` → `timeout 7s` | Extra headroom for N100 PMU init |
| `|| true` on pipeline | Absorbs any remaining non-zero exit |
| Positional awk (`$7`, `$13`, `$16`) | Matches `-l` physical engine column layout |
| Removed `OUTPUT=$()` intermediary | Piped directly, no `tr -d '\r'` needed for plain text |

### Column layout (`-l` format, v2.3)

Physical engines in `-l` output:

```
$1  $2   $3   $4  $5    $6     $7   $8  $9  $10  $11 $12  $13  $14 $15  $16   $17 $18
Freq      IRQ  RC6 Power        RCS        BCS         VCS          VECS
req  act  /s   %   gpu  pkg     % se wa    % se wa     % se wa     % se wa
```

- `$7`  = Render/3D (RCS) busy %
- `$13` = Video (VCS) busy %
- `$16` = VideoEnhance (VECS) busy %

## Grafana

The metrics are scraped by Prometheus via the node-exporter textfile
collector. The Grafana dashboard queries:

```
intel_gpu_engine_busy_percent{engine="video"}
intel_gpu_engine_busy_percent{engine="render"}
intel_gpu_engine_busy_percent{engine="videoenhance"}
```

The `intel_gpu_busy_percent` metric is the max of all three engines
at each sample.
