---
name: yoga-power-audit-2026-09-19
description: Battery tuning round 2 — audit verdict, battery-refresh module
  (both sessions), runtime-pending verifications
metadata:
  node_type: memory
  type: project
  originSessionId: sess_9982d629-7fbd-4b6b-8985-4a6c234b96a9
---

2026-09-19 battery audit: config was already ~90% of achievable (live-verified on battery: amd-pstate-epp + powersave + EPP balance_power on all 16 CPUs, no daemon fights — system76-scheduler only touches CFS knobs). Added: `home/battery-refresh.nix` (`desktop.battery-refresh.*`, 120→60Hz panel switch, Hyprland hyprland.start daemon + GNOME systemd user service via gnome-monitor-config/gmc; panel def comes from `desktop.hyprland.monitors` set host-side for BOTH attrs) and Brave `--enable-features=VaapiVideoDecodeLinuxGL` (nixpkgs wrapper already adds AcceleratedVideoDecodeLinuxGL — decode was already on). QC green incl. behavioral daemon tests (dock/lid guards). Full status + deliberately-not-done list (PSR, powertop, charge cap…) documented in REPO_OVERVIEW § "Power tuning status (yoga)".

**Runtime-pending (cannot verify from sandbox):** gmc `0-unstable-2023` against mutter 50.4 in .#yoga-gnome (if broken: no switching, daemon logs apply error — no other damage); brave://gpu + chrome://media-internals decode check; live 120→60 switch in both sessions. 2026-09-27: Hyprland-session battery-refresh user unit confirmed ACTIVE on battery (panel switch itself still unverified from sandbox — hyprctl unreachable, no /tmp/hypr sig); see [[yoga-battery-drain-2026-09-27]].

Discovered: Lenovo conservation mode sysfs exists at `/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/VPC2004:00/conservation_mode` (0=off) — no charge_control_end_threshold on this EC; only enable on explicit request (see [[user-communication-style]] — behavior changes need user sign-off).

Gotcha hit during QC: `writeShellApplication` returns a package dir — references must append `/bin/<name>` (unit + Lua hook initially pointed at the dir; would have failed at start).

2026-09-30 update: battery STAPM/SLOW 18→15W in `hosts/yoga/default.nix` (FAST stays 25W = latency knob). Verified live pre-change: ryzen-tdp-control applies cleanly every 5 min via ryzenadj-through-ryzen_smu; 28.3W constant load = 18W package + ~10W board/screen; live power_now 27.98W. STAGED uncommitted, QC green (fmt + eval + dry-build yoga) — needs user switch (watchdog keeps 18W until then; switch restarts the service, no manual step). User fallback if sustained work feels slow: raise to 16W.
