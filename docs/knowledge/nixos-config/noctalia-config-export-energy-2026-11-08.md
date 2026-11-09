---
name: noctalia-config-export-energy-2026-11-08
description: Noctalia live-config harvest into nix + energy timeline redesign
  (kbd 60s, lock 5min/5s grace, screen-off 5.5min, suspend 25/90 battery/AC via
  hooks) — EXECUTED+QC green STAGED, switch pending (sudo blocked)
metadata:
  node_type: memory
  type: project
  originSessionId: session_69e7b8e5e30438ffe75ab7cc7c0f8dd2
---

EXECUTED + QC green (test-suite fast ×4 attrs, home-files build ran `noctalia config validate` ✓) **STAGED, SWITCH PENDING** — agent cannot sudo (no-new-privileges, sandbox AND unsandboxed), user must run `sudo nixos-rebuild switch --flake .#yoga-niri`. State strip + shell restart already done live.

**What was done (2026-11-08):**
- Harvested the full GUI drift from `~/.local/state/noctalia/settings.toml` into `home/noctalia.nix` (bar geometry 28/5/20/0.59 frost/pills 0/scale 1.05/font 0.9; theme Rose Pine Alt + faithful + templates OFF; shell/notification/monitor/widget knobs; login-box box_height 70 + reveal/layout/session buttons). State file STRIPPED while shell stopped (backup: `settings.toml.bak-2026-11-08`) → Nix is layer of record again. Closes the pending `config export merged` reconciliation from [[shell-strategy-converge-niri-noctalia-2026-11-07]].
- Energy timeline (user spec): `pre_action_fade_seconds = 0`; behaviors kbd-off 60s (custom: zero `platform::kbd_backlight` max=2, save level double-fire-safe, resume restores unless locked) / lock 300s + `grace_period_seconds = 5` (passwordless window) / screen-off 330s / suspend 1500s `lock_and_suspend` battery baseline. Hooks (TOML snake_case): started/battery_charging/battery_discharging → one probe script `config-set`s suspend timeout 5400 on AC (25/90 split, user-approved; config-set persists that ONE key into state — accepted, started re-derives each start). session_locked → kbd off, session_unlocked → restore. s2h ([[yoga-hibernate-status]]) confirmed pure-systemd, fires on any suspend — untouched.
- Cleanups: `/var/lib/noctalia-greeter` persisted (mutable sync.toml was lost per boot); dead `.config/dms` + `.local/state/dms` persistence dropped; dormant kitty Rosé-Pine/noctalia branches removed from home/terminal.nix (kitty never evaluates on niri attr).

**Why:** GUI state won per-key over Nix with no build gate covering it; user wanted declarative reproducibility + the new energy targets.

**How to apply (schema/IPC lore, probe-proven):**
- `noctalia msg config-set` parses values as TOML: strings need `'"custom"'` quoting, arrays work as JSON `'["a","b"]'`; it writes the state layer immediately (mtime bump).
- Idle behaviors with no `action` are IGNORED ("needs an action" warning); `idle.pre_action_fade_seconds` applies to EVERY behavior incl. `action = "custom"` (kbdtest probe 2026-11-08) — any sub-lock custom behavior must run with fade 0.
- Hooks section: `[hooks]` keys are snake_case (`battery_charging`), values = command arrays; `hooks kinds with commands=N` logged at load.
- `lib.getExe pkg` in a PATH export is a FILE not a DIR — use `${pkg}/bin`. `pkgs.grep` attr is gone → `pkgs.gnugrep`. statix gate flags repeated `widget.x = …` keys → merge into one `widget = { … }`.
- Restarting noctalia.service while locked UNLOCKS the session (lock surface dies with the old process; new instance starts unlocked) — re-lock via `noctalia msg session lock` right after.
- `noctalia msg status` JSON: `"locked": true/false` (pretty-printed) — grep-able.
- Script PATH inside hook/idle shells cannot be assumed: absolute store paths + exported PATH throughout ([[noctalia-lockscreen-soft-round2-2026-11-07]] systemd-run lore).

**Post-switch live checklist (pending):** behaviors=4 in log; kbd off ≤60s idle → back on activity, dark while locked, returns after unlock; lock at 5:00 w/ 5s grace; screen-off 5:30; AC unplug/plug flips suspend timeout (`noctalia msg config-get idle.behavior.suspend.timeout`); suspend+resume; s2h still arms RTC on battery.
