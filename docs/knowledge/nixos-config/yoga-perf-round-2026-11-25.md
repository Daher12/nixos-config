---
name: yoga-perf-round-2026-11-25
description: Yoga perf/power round EXECUTED+fast green STAGED (uncommitted) —
  system76-scheduler removed, TLP 3-profile+tlp-pd, STAPM-inert-on-Rembrandt,
  watermark 125, power-probe kit; OPEN = user checks (Brave VA-API, Obsidian
  ozone), baseline, TDP/EPP/zstd A/Bs, scx+preempt experiments, VM battery ask
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e4419bd0-2cc1-40d5-bfe8-c014b6c9e19f
---

2026-11-25 yoga performance round (plan approved by user; priorities = sustained perf/thermals + memory headroom + battery runtime; all three experiments OK; user runs measurements). Everything STAGED-UNCOMMITTED, `test-suite fast` green (yoga+latitude+nix-media), spot-checked via `nix eval --impure --expr`.

**Executed (config):**
- system76-scheduler REMOVED from profiles/laptop.nix (verified no D-Bus caller: busctl shows daemon owns `com.system76.Scheduler` alone; journal hits were nix-gc store paths). Rationale: foreground boost needs GNOME/COSMIC focus reporting — niri has none; cost was execsnoop (~200MB RSS peak) + renice-on-every-exec (user apps sat at nice 9). `modules/features/kernel.nix` now pins `sched_autogroup_enabled=0` = the long-effective value (system76 had forced it 0 over the old `=1`).
- TLP (hosts/yoga/default.nix + modules/features/power-tlp.nix): `TLP_DEFAULT_MODE` deleted (dead under TLP_AUTO_SWITCH=2 — verified against 1.9.1 tlp-func-base); `CPU_BOOST_ON_SAV=0` (TLP 1.9.1 SAV defaults already EPP=power/platform=low-power/ABM=3; boost fell back to BAT); new `features.power-tlp.pd` option → `services.tlp.pd` (tlp-pd D-Bus switcher, `tlp-stat -m` queries, `sudo tlp power-saver`/`performance`/`balanced`/`start` CLI) — ON for yoga, off latitude. Module governor default schedutil→powersave (schedutil invalid under pstate active; bitten latitude only).
- ryzen-tdp.nix: STAPM is INERT on Rembrandt (ryzenadj wiki matrix: ⚠ no effect; clock caps ⛔) — effective sustained cap = SLOW, burst = FAST, Tctl bounds temp. Log lines + option descriptions corrected; script now also logs `ryzenadj --info` after apply.
- zram.nix: `algorithm` option (default lz4 everywhere, latitude unchanged) + `vm.watermark_scale_factor=125` (mkDefault; yoga showed pgscan_direct 6.3M + 7.9GB user-slice swap.peak).
- brave.nix: `MemorySaverEnabled=true` managed policy (Brave RSS peak was 4.5GB).
- scripts/test-suite: `full <host>` no longer forwards host names to the VM tier (died "Unknown VM test").
- NEW `scripts/power-probe` (staged, +x): `sudo power-probe idle [secs]` / `load [secs] [--ryzenadj "args"]` — turbostat --Summary parse (PkgWatt/GFXWatt/PkgTmp/Bzy_MHz), battery W, Tctl (k10temp), fan (yogafan, monitoring-only), stress-ng metrics; --ryzenadj pauses ryzen-tdp-watchdog.timer + restores via trap.

**Key research facts (don't re-derive):** TLP on box = 1.9.1 (NOT 1.11 — three profiles already exist; `tlpctl`/tlp-pd come from the SEPARATE nixpkgs pkg `tlp-pd`, wired by `services.tlp.pd`, asserted vs ppd which power-tlp.nix already forces off). EPP choices include `dynamic` (kernel follows platform profile). yogafan = RPM only, no pwm. ryzen_smu on this box: amkillam fork d298366 (nixpkgs pin for 7.2+ cpuid fix), Rembrandt codename 11, NO PM table. sched_ext compiled in (state=disabled) — nixpkgs enables ≥6.12; `services.scx` exists (default scx_rustland — must set explicitly), no conflict assertion vs system76. zen kernel = PREEMPT_DYNAMIC, nixpkgs default mode is lazy on ≥6.18 (PREEMPT=no/LAZY=yes) — `preempt=full` is the classic-low-latency experiment. Kernel thermal zone: only critical 110°C (firmware EC owns fan/skin). Battery: L21D4PE0 60Wh/70Wh (283 cycles), quiet desktop ≈7.5W, charge_types `[Fast] Standard Long_Life` exists (charge cap now technically reachable via charge_types/conservation_mode — declined twice, don't re-offer unprompted). Memory: ZCode ~4GB/19 procs (0.84GB MCP servers), Brave ~1GB (peak 4.5GB), noctalia.service cgroup holds the Brave tree + foot.service holds a 2nd ZCode instance (cgroup≠app attribution). user@1000 swap.peak 7.9GB. NVMe scheduler on zen = kyber (not none — boot.nix comment about kernel default is stale on zen; left alone deliberately).

**OPEN (user steps, in order):**
1. Two 10s checks: brave://gpu "Video Decode" (if not "Hardware accelerated" → merge the duplicated `--enable-features` in hosts/yoga/home.nix:309 — nixpkgs wrapper already passes AcceleratedVideoDecodeLinuxGL etc. and Chromium keeps the LAST flag); `pgrep -af obsidian` for ozone flags (if XWayland → add `systemd.user.sessionVariables.NIXOS_OZONE_WL = "1"` in home/default.nix, same pattern as XCURSOR_*).
2. Baseline + A/Bs with power-probe: idle on battery (balanced vs `sudo tlp power-saver`), `load 300 --ryzenadj` variants V0 60/50/85 (current) vs V1 60/54/95 (module defaults) vs V2 45/40/80 on AC; adopt per plan rules (≥5% throughput / cooler = V2; <0.3W = noise).
3. EPP=dynamic A/B at runtime; zram zstd A/B (switch `features.zram.algorithm`, reboot); optional scx_lavd + `preempt=full` (expect revert; fold into the pending 7.3.5 reboot).
4. ZCode MCP trim: `ps -eo rss,pid,args --sort=-rss | grep -E "zcode-mcp|mcp-nixos"` → disable unused servers in ZCode settings (~100–170MB each); quit the duplicate ZCode instance.
5. VM battery NOT run (gate): `suggest` maps zram.nix→zram-heal+yoga-s2h-logic, modules/features+profiles+hardware→host-units-smoke; asked user full/partial/skip.
6. After switch+reboot verify: `tlp-stat -m`, panel ABM per profile, `zramctl`, sysctls, `ryzenadj -i`, system76 units gone.

REPO_OVERVIEW synced (power-tlp/zram/laptop profile/test-suite rows, scripts table + §Power tuning round-2 paragraph). Related: [[yoga-power-audit-2026-09-19]], [[battery-refresh-niri-backend-2026-11-07]], [[niri-vrr-edp1-2026-11-19]], [[yoga-ram-baseline-system76-execsnoop]], [[zcode-battery-alternatives-plan-2026-11-25]].
