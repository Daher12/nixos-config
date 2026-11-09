---
name: noctalia-export-energy-plan-2026-11-08
description: PLAN ready, NOTHING executed (ExitPlanMode DENIED 2026-11-08) —
  harvest live Noctalia state into Nix + energy/idle targets (lock 5min/grace
  5s, screen-off 5.5, kbd-off 60s, suspend 25bat/90ac via hooks) + 3 cleanups;
  full live-drift table + Noctalia v5.4.1 hooks/idle schema facts
metadata:
  node_type: memory
  type: project
  originSessionId: session_69e7b8e5e30438ffe75ab7cc7c0f8dd2
---

PLAN approved via AskUserQuestion, ExitPlanMode DENIED → NOTHING executed. Three goals on `niri-testing` attr `yoga-niri`, one switch.

## User decisions (locked)
1. Suspend split **25 min battery / 90 min AC via Noctalia hooks** (runtime `config-set`, writes one key into state layer). Fallback single 45min only if hooks prove unreliable.
2. Include all 3 cleanups: persist `/var/lib/noctalia-greeter`, drop dead `.config/dms`+`.local/state/dms` persistence entries, remove dormant kitty Rosé-Pine branches in home/terminal.nix.
3. **Skip VMs** (HM-config only; gate = test-suite fast + real home-files build which runs `noctalia config validate` — dry-build does NOT run the validator).

## Energy targets → Noctalia idle config (home/noctalia.nix)
- behavior_order ["kbd-off","lock","screen-off","suspend"]; lock 300s, screen-off 330s, suspend 1500s baseline `lock_and_suspend`, keep `lock_before_suspend=true` (covers lid/manual).
- `lockscreen.grace_period_seconds = 5` = passwordless unlock window (live was 1); `fingerprint=false` live.
- kbd backlight (sysfs `platform::kbd_backlight`, max 2): custom idle behavior timeout 60s + `session-locked`/`session-unlocked` hooks; restore only if NOT locked (`noctalia msg status` reports `locked`); save value to `$XDG_RUNTIME_DIR/noctalia-kbd-saved` via writeShellScript + brightnessctl.
- AC split hooks: `battery-charging`→config-set suspend.timeout 5400; `battery-discharging`→1500; `started`→probe AC (reuse pkgs/is-on-ac or inline /sys glob).

## Verified facts (2026-11-08, live + repo probes)
- **Noctalia owns ALL idle** on yoga-niri (no swayidle/hypridle; logind IdleAction=ignore, lid-suspend-battery only). Current LIVE (state wins over Nix): lock 180s, screen-off 185s, suspend 2400s lock_and_suspend, order lock→screen-off→suspend. Nix baseline stale at 180/300/900.
- **Live drift table** (state `~/.local/state/noctalia/settings.toml`, mtime 11-07 21:40): bar.main opacity 0.59/thickness 28/margins 5-20/padding 10/scale 1.05/font_scale 0.9/capsule_opacity 0.0 (full-bar redesign, pills gone); theme +community_palette "Rose Pine Alt", wallpaper_scheme faithful, enable_builtin_templates **false**; shell +show_close_buttons false, panel control_center_placement floating, screen_corners 14, window_switcher mru/compact; notification 3h/overlay/2; system.monitor disk 60 gpu 10; widget.network/volume tweaks; desktop_widgets disabled; lockscreen widgets login box box_height 70 + show_session_buttons/password_reveal/keyboard_layout true.
- Noctalia v5.4.1 capabilities (binary-proven): `[idle.behavior.<name>]` arbitrary names, action enum lock|screen_off|suspend|lock_and_suspend|custom with `command`+`resume_command`+`locked_timeout`; `pre_action_fade_seconds` dim; **hooks events**: started, session-locked/unlocked, battery-charging/discharging/plugged, power-profile-changed, wallpaper-changed etc (18); IPC `config-set`/`config-get`, `keyboard-backlight-set 0-100`, `caffeine-toggle`, `power-set` (PPD — inert here, TLP host, PPD disabled); `noctalia config export full` dumps all 428 registry defaults. No schema.json ships — schema embedded in binary.
- **s2h script independent** (user's question answered yes): yoga-s2h = /etc/systemd/system-sleep hook, pure systemd, fires on ANY suspend incl. Noctalia idle; unchanged by plan. New timeline: idle-suspend 25min → RTC +2h → hibernate ≈2h25m; MAX_OPENLID=2 intact; AC suspend at 90min just suspends (no RTC on AC by design).
- State reconcile procedure: backup settings.toml → `systemctl --user stop noctalia` (KillMode=process keeps children incl. agent session alive — proven) → strip whole file (everything mirrored) → switch → verify `config export merged` ≈ Nix baseline (only residue = hook-set suspend timeout), log shows `idle behaviors=4`.
- Pre-flight probes REQUIRED before writing nix (probe-first lore): `noctalia config export full` for exact `[hooks.*]` TOML shape; validate candidate TOML via `noctalia config validate <file>` (warnings pass build gates silently — grep manually).
- Audit verdict: declared side clean (tag-pinned inputs, upstream HM module, cachix, KillMode override). Other flaws noted-only: hand-synced greeter literals, lucid-input font coupling (documented in-file), machine-specific widget geometry. Home impermanence for noctalia complete; system side missing only /var/lib/noctalia-greeter.

Related: [[noctalia-niri-swap-exec-2026-11-06]] (schema/state-layer lore), [[shell-strategy-converge-niri-noctalia-2026-11-07]] (its pending "config export merged" reconciliation = this plan), [[yoga-hibernate-status]] (s2h).
