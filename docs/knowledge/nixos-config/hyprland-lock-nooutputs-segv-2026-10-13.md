---
name: hyprland-lock-nooutputs-segv-2026-10-13
description: Hyprland 0.55.4 SEGV when session lock arrives with zero enabled
  outputs (lid-close suspend race) — diagnosed + approved plan EXECUTED 2026-10-14,
  QC green, STAGED uncommitted
metadata:
  node_type: memory
  type: project
  originSessionId: sess_1f16a424-3eaf-476d-9902-ccd34edba7af
---

Hyprland crashed after suspend 2026-10-13 23:31 (boot 0, yoga). NOT GPU/suspend — kernel log clean.

**Root cause (proven):** lid close on battery → logind PrepareForSleep → hypridle `before_sleep_cmd = qs ipc call lock lock` races the Hyprland lid bind `home/hyprland.nix` lidSwitchLua (`hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'`). When the disable wins, quickshell logs "There are no outputs - creating placeholder screen" and Hyprland 0.55.4 SEGVs in `CSessionLockManager::onNewSessionLock → CSeatManager::setGrab → CWorkspace::isVisibleNotCovered()`. Crash report of record: `~/.cache/hyprland/hyprlandCrashReport166486.txt` (keep for upstream issue). Earlier suspends same day survived = race, lock won those times. coredumps are discarded on this host (`core_pattern` pipes to `false`) — Hyprland's own crash report is the only trace.

**Key live-state fact:** after the crash uwsm restarted the compositor with `--safe-mode` = stock config ("No config file found") — desktop runs degraded until logout/login; don't misread as lost config.

**Upstream:** no exact issue filed; v0.56.0 has "renderer: fix SEGV on monitor disconnect" (unverified for this path); discussion #15702 = same family. nixpkgs-26.05 stays 0.55.4. nix MCP channel info again served STALE hyprland version (0.54.3) — see [[verify-versions-against-deployed-system]].

**EXECUTED 2026-10-14 (executor session), QC all green, STAGED UNCOMMITTED, no switch yet:**
- Chose shell-guard fallback (0.55.4 Lua API exposes NO monitors accessor — only setters in the stock `hyprland.lua`).
- `home/hyprland.nix`: close bind now `if [ "$(hyprctl monitors | grep -c '^Monitor ')" -gt 1 ]; then hyprctl eval '…disabled=true…'; fi`; comment block documents rationale. `hyprctl monitors` lists only enabled monitors (disabled only under `monitors all`) — pattern verified live. Guard live-tested: solo monitor → BLOCK.
- REPO_OVERVIEW.md § Known Gotchas entry added after the `hyprctl keyword monitor` one, incl. ⚠️ warned repro (`hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})' && qs ipc call lock lock` crashes live session).
- QC: `nix fmt` clean; home-files byte-diff = exactly the one bind line; full generated `hyprland.lua` parses (`nix-shell -p lua --run "luac -p …"` — host has no luac/nvim); `nixos-rebuild dry-build --flake .#yoga` green.
- Nix-quoting gotcha: `lidSwitchLua` is an indented string, so `\"` stays literal `\"` in the generated file = Lua-escaped quote (mirrors the pre-existing working line; a plain double-quoted Nix string would emit a raw `"` and break Lua parsing).

User follow-ups: switch via `nus` → logout/login (clears safe-mode instance; crash already lost those windows) → live-verify: docked lid-close still disables eDP-1, solo lid-close suspend = no crash + lock screen on resume. Optional: upstream issue draft from crash report. Related: [[yoga-fnlock-frow-2026-10-06]], [[lucid-hardening-quickshell-flake-2026-09-30]], [[desktop-switch-architecture-2026-10-13]].
