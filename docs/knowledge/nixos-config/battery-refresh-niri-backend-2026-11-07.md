---
name: battery-refresh-niri-backend-2026-11-07
description: niri backend for battery-refresh + explicit panel mode EXECUTED,
  live-proven end-to-end, staged on niri-testing; niri mode-grammar facts in
  file
metadata:
  node_type: memory
  type: project
  originSessionId: session_66443f41bdb8937df50624253db14b25
---

EXECUTED 2026-11-07, QC green ×2 + live functional proof, STAGED on niri-testing (no commit). Fixes [[noctalia-niri-swap-exec-2026-11-06]]'s known gap: on the niri attr the panel sat at 60 Hz in BOTH power states (user noticed "battery 60/AC 120 not working" — direction was inverted: 120 was missing, not the 60-on-battery).

**Root causes (both, fixed together):**
1. `modules/features/desktop-niri.nix` had `battery-refresh.enable = mkForce false` (only hyprctl/gnome-monitor-config backends existed) → unit not-found in the switched generation.
2. `home/niri.nix` omitted the output `mode` believing "niri auto-picks highest" — niri actually picks the panel's PREFERRED mode, and this EDID pins preferred at 60 Hz.

**Fix:** niriDaemon `writeShellApplication` in `home/battery-refresh.nix` (third backend; `daemonText` now takes acMode/batMode params because niri's mode grammar differs); selector niri > Hyprland > GNOME (explicit order; during the trial a Hyprland-backend unit once crash-looped against live niri — hyprctl connection error piped into jq = parse-error spam every poll); `desktop-niri.nix` dropped the mkForce; `home/niri.nix` output block now `mode "3072x1920"` (resolution-only = highest refresh for it).

**niri 26.04 facts (verified live):**
- Mode grammar matches EDID strings EXACTLY, three decimals: `3072x1920@60.000` ok, plain `@60` never matches. Resolution-only `"3072x1920"` = highest rate for that resolution (→ 120.002). Same grammar in config.kdl and `niri msg output <o> mode <m>` (IPC hot-apply; validated both).
- `niri msg -j outputs`: top-level keyed by output name; `modes[]` = {width,height,refresh_rate MILLIHERTZ,is_preferred}; `current_mode` = INTEGER INDEX into modes. Probe: `.["eDP-1"].modes[.["eDP-1"].current_mode].refresh_rate / 1000 | round`.
- NIRI_SOCKET **is imported into the systemd user manager** by niri-session (`systemctl --user show-environment` shows it) → daemon needs no env wiring. Socket name `niri.<WAYLAND_DISPLAY>.<niri-pid>.sock` changes per session.
- EDID panel: preferred = 60000 mHz, 120002 mHz available. `niri validate` build gate (home/niri.nix) accepts resolution-only mode.
- On yoga-niri attr `desktop.hyprland.enable = false` (HM side), despite the shared `desktop.hyprland.monitors` namespace carrying the panel list.

**Live proof:** built daemon binary run against the session — forced 60 → logged `battery-refresh: eDP-1 at 60 Hz, restoring 120 Hz (ac)` → panel 120.002 within one poll; no-op tick at 120 silent. Panel left at 120 (on AC).

**Pending user:** `nus` switch, then `systemctl --user start battery-refresh` ONCE (newly-wanted user unit doesn't auto-start mid-session) or relogin; unplug/replug AC to see both directions. REPO_OVERVIEW synced (desktop-niri row, battery-refresh row, §Power tuning paragraph). daemonText signature change = hyprland/gnome call sites updated, fast suite green on all three attrs (yoga/yoga-niri/yoga-gnome).

**QC round (same day, user-requested):** gate green ×3 total. Proven per attr from built home-files: yoga → hyprland daemon (hyprctl, `@120`/`@60`, no ext guard), yoga-gnome → gnome daemon (gnome-monitor-config, ext guard), yoga-niri → niri daemon = the live-tested store path `2vcsfr9…` (unchanged after QC edits). **Byte-identical refactor proof:** first gate run scheduled NEW battery-refresh drvs ONLY under yoga-niri — Hyprland/GNOME daemon derivations were already in the store → acMode/batMode parametrization changed nothing for them. QC fixed 4 stale "both sessions" wordings (battery-refresh.nix ×3 incl. the assertion message, hosts/yoga/home.nix panel comment). Lore: `nix eval …systemd.user.services.X.Service.ExecStart` printed nothing — inspect the built unit file instead.
