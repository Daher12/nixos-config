---
name: yoga-perf-round-2026-11-25
description: Yoga perf/power round — EXECUTED, MEASURED, QC'd 2026-11-25; main
  part committed in cb7b73e (not by me), QC follow-ups uncommitted in working
  tree; QC found+fixed a live TLP key-name bug (boost leak) and a bogus Brave
  policy — durable lessons on "rendered ≠ consumed"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e4419bd0-2cc1-40d5-bfe8-c014b6c9e19f
---

2026-11-25 yoga performance round (plan approved; priorities = sustained perf/thermals + memory headroom + battery runtime; user ran the measurements). **State:** main config landed in commit `cb7b73e feat(perf)` + `2b25eb2 docs(knowledge)` — committed by the user / a parallel session, NOT by me. The QC fixes below are uncommitted working-tree edits on top (fast tier green).

**Executed (config, corrected after QC):**
- system76-scheduler REMOVED from `profiles/laptop.nix` (no D-Bus caller: daemon owned `com.system76.Scheduler` alone). Foreground boost needs GNOME/COSMIC focus reporting — niri has none. Verified live after reboot: units gone, desktop processes (niri/noctalia/foot/ZCode) now nice 0 (were nice 9). `modules/features/kernel.nix` pins `sched_autogroup_enabled=0` = the previously forced effective value (live: 0).
- TLP (`hosts/yoga/default.nix`, `modules/features/power-tlp.nix`): `TLP_DEFAULT_MODE` deleted; new `features.power-tlp.pd.enable` (mkEnableOption) → `services.tlp.pd`, on for yoga, off latitude (tlp-pd live: `tlp-stat -s` → `tlp-pd = enabled, running`); module governor default schedutil→powersave (latitude runs intel_pstate active — only powersave/performance valid, so neutral there).
- Boost per profile, **TLP 1.9.1 key names**: `CPU_BOOST_ON_AC=1 / CPU_BOOST_ON_BAT=1 / CPU_BOOST_ON_SAV=0` (power-saver = boost off, others explicitly on).
- `modules/hardware/ryzen-tdp.nix`: STAPM write does not stick on Rembrandt — **on-device proof**: the `ryzenadj --info` table the service now logs shows `STAPM LIMIT 59.967` right after `Successfully set stapm_limit to 50000`, while fast/slow/Tctl read back as set. Effective knobs = SLOW (sustained), FAST (burst), Tctl.
- `modules/features/zram.nix`: `algorithm` option (default lz4 everywhere) + `vm.watermark_scale_factor=125` (live: 125; standard zram tuning, small expected effect).
- `modules/features/brave.nix`: **no Memory-Saver policy** — `MemorySaverEnabled` is not a Brave policy (see QC). User enables it in `brave://settings/performance`.
- `hosts/yoga/home.nix`: ONE merged `--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,VaapiVideoDecodeLinuxGL` (Chromium keeps only the last occurrence; the old single-feature flag silently dropped the wrapper's). Verified live: `brave://gpu` Video Encode went "Software only" → "Hardware accelerated".
- `scripts/test-suite`: `full <host>` no longer forwards host names to the VM tier.
- NEW `scripts/power-probe`: `idle [secs]` / `load [secs] [--ryzenadj "args"]`; three live-use fixes (EXIT-trap restore scope via global `PP_RESTORE`; no `stress-ng --quiet` because it eats the metrics; battery column prints its state).

**Measurements & decisions (all closed):**
- Idle on battery: 6.95 W (PkgWatt 0.68) balanced ≡ 6.93 W power-saver — idle is panel/platform-bound; power-saver matters under load.
- TDP on AC: V0 (60/50/85) ≡ V1 (60/54/95) ≡ V2 (45/40/80): sustained PkgWatt ~26–29 W, ~3.1 GHz regardless of slow limit → firmware skin-temp policy governs sustained power; AC caps only shape the burst; battery 15 W cap does bind. **V0 kept.** V2 = hotter peak (78 °C) at the same 3900 rpm fan, ~1.5 % less throughput. All load runs were boost-off (leak below) — verdict unaffected (clamp is power-based).
- Experiments: EPP `dynamic` skip; zram zstd pass (user: lz4 fits their usecase); `scx_lavd` declined (unknown battery drain); `preempt=full` declined — lazy stays.
- VM battery skipped by user choice (suggest mapped zram-heal, yoga-s2h-logic, host-units-smoke; untouched code paths).

**QC 2026-11-25 — defects found in my own work, all fixed:**
1. **Boost "fix" used TLP 1.11 key names** (`CPU_BOOST_ON_PRF/_BAL`); TLP 1.9.1 reads `_ON_AC/_ON_BAT/_ON_SAV` (`func.d/10-tlp-func-cpu:408-410`) and ignores unknown keys WITHOUT warning. So the leak was still live on the booted system (boost=1 only because of the fresh reboot) after I had told the user it "can't recur". Fixed + verified against the TLP source; takes effect at the user's next `nixos-rebuild switch` (no reboot needed — `tlp.service` restarts on tlp.conf change). Post-switch proof: `sudo tlp power-saver; cat /sys/devices/system/cpu/cpufreq/boost; sudo tlp start; cat /sys/devices/system/cpu/cpufreq/boost` → 0 then 1.
2. **`MemorySaverEnabled` was a guessed policy name** — not in Brave 1.100.58's binary (string-table check; `HighEfficiencyModeEnabled` / `MemorySaverModeSavings` exist with different semantics). It was a no-op; removed.
3. **"Battery assist" explanation was wrong**: the falling `bat` watts during the AC load runs were CHARGE power tapering as the cell filled (82 % → Full), not battery assist and not the clamp. The clamp conclusion rests on turbostat PkgWatt.
4. **Overstated evidence** for watermark 125: the cited 7.9 GB user-slice `memory.swap.peak` is inflated by hibernation-time reclaim, not proof of steady-state pressure. Comment + docs corrected; setting kept.

**Lessons (durable):**
- **Rendered ≠ consumed.** `nix eval` of a generated config file proves a key is WRITTEN, not that the program READS it. Before adding/renaming any daemon setting, grep the deployed package's source for the variable (`/nix/store/*-<pkg>-<ver>/share/...`). Docs sites show the newest version — the box may run an older one (TLP 1.9.1 vs 1.11 docs).
- **Never add policy/flag names from memory** — check the binary's string table (`grep -a -o '<Name>' <ELF>`) or the app's policy page first.
- **A bug fix needs its own end-to-end test** (exercise the consumer's code path or the live round trip), not just "it renders".
- `BAT0 power_now` on AC = charge power (positive, tapers as the cell fills); only meaningful for system draw when discharging.
- cgroup `memory.swap.peak` is not evidence of runtime memory pressure on a hibernating host.
- `pgrep -f`/`grep` patterns match the calling shell's own command line (the pattern text appears in it) — use `ps | grep '[s]tring'` and keep the literal name out of the rest of the command.
- Other sessions / the user commit in this repo mid-conversation: check `git log` + `git status` before stating "nothing is committed".

**Still open (user side):** rebuild+switch to activate the QC fixes, then the boost round-trip check above; optional ZCode MCP trim (`ps -eo rss,pid,args --sort=-rss | grep -E "zcode-mcp|mcp-nixos"`, ~100–170 MB per server); commit the QC follow-ups on request.

**Key research facts (don't re-derive):** TLP on box = 1.9.1; three profiles exist; `tlpctl`/tlp-pd come from the separate nixpkgs pkg `tlp-pd` (`services.tlp.pd`). Profile switching: `sudo tlp performance|balanced|power-saver`, `sudo tlp start` returns to auto; query `tlp-stat -m` (profile) / `tlp-stat -s` (daemon lines). EPP choices include `dynamic`. `yogafan` = RPM monitoring only. ryzen_smu: amkillam fork d298366, Rembrandt codename 11, no PM table. sched_ext compiled in, unused; `services.scx` default `scx_rustland`. zen = PREEMPT_DYNAMIC, boots lazy. Kernel thermal zone: only critical 110 °C. Battery L21D4PE0 60/70 Wh, 283 cycles; `charge_types [Fast] Standard Long_Life` (charge cap declined twice — don't re-offer). Sandbox trap: agent shells see an overlaid `/etc` — `tlp-stat` reports `tlp = disabled` from there; host truth = `/run/tlp/run.conf`, `/sys`, journal.

Related: [[yoga-power-audit-2026-09-19]], [[battery-refresh-niri-backend-2026-11-07]], [[niri-vrr-edp1-2026-11-19]], [[yoga-ram-baseline-system76-execsnoop]], [[zcode-battery-alternatives-plan-2026-11-25]], [[zcode-shell-sandbox-etc]].
