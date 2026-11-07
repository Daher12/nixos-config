---
name: battery-refresh-niri-broken-2026-11-06
description: VERIFIED live 2026-11-06 — battery-refresh (60Hz bat/120Hz ac) dead
  on niri session, panel stuck 60Hz even on AC; root causes + grounded niri IPC
  facts + ready fix plan; ExitPlanMode DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: session_66443f41bdb8937df50624253db14b25
---

VERIFIED 2026-11-06 (plan-mode diagnosis, ExitPlanMode DENIED → fix plan built but NOTHING executed; branch niri-testing working tree). User reported the refresh-rate feature "isn't working anymore" — CONFIRMED, and inverted vs their assumption: panel stuck at **60 Hz in BOTH states** (on AC at report time), losing 120 on AC entirely.

**Root causes (both deliberate-but-wrong decisions in [[noctalia-niri-swap-exec-2026-11-06]]):**
1. `modules/features/desktop-niri.nix` ≈104: `battery-refresh.enable = lib.mkForce false` (only hyprctl/GNOME backends existed). Unit `not-found` in current gen.
2. `home/niri.nix` omits the output `mode` claiming "niri auto-picks the highest refresh rate" — FALSE: niri picks the panel's **preferred** mode; this yoga panel's EDID prefers 60 Hz.

**Journal residue explains the transient:** session start 2026-11-06 16:44 — the stale hyprctl-backend battery-refresh unit crash-looped against niri (jq parse errors every ~5s, RestartSec=5s) until hm-activate stopped it 16:46:28. Not running now.

**Session ground truth (niri/Noctalia live since 16:44):** niri socket = `/run/user/1000/niri.wayland-1.<pid>.sock`; `NIRI_SOCKET`+`WAYLAND_DISPLAY` ARE imported into the systemd user manager (verified via show-environment) → `niri msg` works from user services, no extra wiring. `desktop.hyprland.enable` is TRUE on the niri attr (why the hyprctl backend got picked pre-mkForce) — backend selector must check niri FIRST.

**niri IPC/mode facts (source-verified + live):**
- `niri msg -j outputs` → `{"eDP-1": {...}}`; `modes[]` objects `{width, height, refresh_rate (INTEGER MILLIHERTZ: 60000/120002), is_preferred}`; `current_mode` = INDEX into modes (not string).
- `niri msg output <OUT> mode <MODE>` hot-applies, "temporary, not saved"; `auto` = automatic.
- Mode string grammar (wiki): omitted mode entirely → preferred; `mode "3072x1920"` (refresh omitted) → **highest refresh for that resolution** (=120.002 here — the clean fix, no EDID-precision hardcoding); with refresh, must match exactly to THREE decimals ("120", not "120.002" ≠ match; "3072x1920@60.000" safe for battery mode).

**Ready fix plan (executed nothing):** Step 0 live probe/relief `niri msg output eDP-1 mode "3072x1920"` (validates grammar + restores AC 120); Step 1 `home/niri.nix` add `mode "3072x1920"` (strip @Hz from shared panel.mode) + fix wrong comment; Step 2 `home/battery-refresh.nix` add `niriDaemon` (probe `jq -r '.["eDP-1"].modes[.["eDP-1"].current_mode].refresh_rate / 1000 | round'`; apply `niri msg output eDP-1 mode $1`; AC="WxH", bat="WxH@60.000"; runtimeInputs + niri; selector niri→hyprland→gnome); Step 3 desktop-niri.nix drop mkForce; Step 4 REPO_OVERVIEW sync; Step 5 QC: git add (index rule), nix fmt, `scripts/test-suite fast yoga yoga-niri` + eval config.kdl for mode line + home-files build for the unit; Step 6 user: `nus` switch + `systemctl --user start battery-refresh` once (new-unit gotcha) or relogin. No VMs needed (config generation only).

Precedent chain: this is the third death of this feature — [[yoga-energy-idle-2026-09-22]] (hyprctl keyword no-op), [[battery-refresh-resume-heal-2026-10-24]] (probe-vs-want self-heal), now the niri swap.
