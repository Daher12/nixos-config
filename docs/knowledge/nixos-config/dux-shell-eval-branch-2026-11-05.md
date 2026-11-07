---
name: dux-shell-eval-branch-2026-11-05
description: DMS (dux-shell) replacing lucid on branch dux-shell — EXECUTED +
  full session QC green (probes + Lua-syntax + verbatim lucid path), ALL STAGED
  UNCOMMITTED; pending commit-decision + user switch + smoke
metadata:
  node_type: memory
  type: project
  originSessionId: session_25d87e9d9276e45dd0423f47ebaffeb6
---

EXECUTED 2026-11-05 on branch `dux-shell` (from main @3388242, main untouched, zero commits): DMS = DankMaterialShell rebranded (duxlabs-dev), quickshell shell, evaluated as lucid's replacement per user decision. **Plan/research facts live in [[dux-shell-evaluation-plan-2026-11-04]].**

**Why:** user wants DMS smoothness + lucid looks; official flake module + upstream German retire the 14-patch lucid layer + 318-rule dictionary.

**State (post full-QC 2026-11-05):**
- Input `github:duxlabs-dev/dux-shell/stable` (rev 7627111, dms-shell 2.1.0, preflight-built OK). NixOS module ONLY (`nixosModules.dank-material-shell`, imported in desktop-hyprland.nix:36 imports alongside dank-greeter). Module is **double-opt-in**: `enable` + `systemd.enable` both mkEnableOption — missing = silent no-op dry-build can't catch; found by eval probe, fixed.
- home/dms.nix: `desktop.dms.enable`, grayscale theme store-symlink (home/dms-themes/grayscale/theme.json, byte-verified port of lucid's two faces), settings.json seeded ONCE via activation guard (currentThemeName=custom). No config.d (precedence unverified — deliberate). UPDATE 2026-11-06: config.d precedence VERIFIED source-level at rev 7627111 — drop-ins override settings.json, see [[dms-lucid-look-port-plan-2026-11-06]].
- hyprland.nix: `shellIpc` attrset maps the 7 muscle-memory binds (spotlight/powermenu/hypr toggleOverview/clipboard/dash notifications/settings/lock); `dmsOnlyBindsLua` adds SUPER+N/SHIFT+N workspaces (hyprctl dispatch) + XF86 media/brightness (pactl/playerctl/brightnessctl 10% steps) — lucid's keybinds.json owned those. Screenshots NOT ported (bind live, harvest).
- **QC evidence**: test-suite fast yoga OK ×3 (last after final edit); probes: dms unit ExecStart=`dms run --session` @graphical-session.target ✓, lucid off / gtk off ✓, quickshell pname `quickshell-wrapped` = patch 201 propagates ✓, seedDmsSettings activation renders ✓, persistence .config/dms+.local/state/dms ✓; rendered hyprland.lua = 262 lines, 8 `dms ipc call`, **0** `qs ipc`, luajit parses OK; shellIpc else-branch = original 7 lucid commands VERBATIM (lucid path regression-safe); host-units-smoke.nix has NO lucid/dms assertions → VM battery legitimately skipped.
- **PENDING: uncommitted** — resolved 2026-11-05 by [[branch-split-plan-2026-11-05]]: dms stream becomes 1 clean commit on `dux-shell` (itself a pointer at main, nothing committed); VPS session's hunks go to a separate `vps` branch. Then user switch + smoke: bar parity → theme+dynamic toggle → light/dark schedule (DMS Settings native, then harvest) → frost → German → lock/greeter → idle CPU → patched-qs probe.
- Flip back: profile lines lucid=true/dms=false + `git switch main`. lucid apparatus fully intact.

**Lore (reusable):**
- NixOS unit eval probe = `config.systemd.user.services.<n>.serviceConfig.ExecStart`; HOME-MANAGER units = `…Service.ExecStart` and ExecStart is a LIST (`--raw` fails "cannot coerce a list" = HM unit, not NixOS).
- `nix eval .#…configFile."hypr/hyprland.lua".text` — inner quotes get shell-stripped; wrap as `'"hypr/hyprland.lua"'` in bash.
- bump.yml auto-update list is INCLUSIVE → new manual pins need NO bump.yml change (update-safe usage text only, `--pin dux-shell` added; only lucid has a hard refusal).
- nixpkgs dms-shell 1.4.4 = stale major-version (why flake route); `nix fmt` also updates flake.lock (stage it).
- Known gaps by design: bar/clock/schedule settings NOT seeded (tune live → harvest); GTK theme/icon names on dms path ride gsettings (settings.ini = DMS matugen); greeter theming still reads legacy DankMaterialShell dir (cosmetic, pre-existing); REPO_OVERVIEW.md deferred to adoption round.

Related: [[vps-watchdog-exitnode-plan-2026-11-01]] (parallel session owning the shared index), [[plans-for-weaker-executor]], [[niri-dms-yoga-plan-2026-11-05]] (sibling plan that would reuse this DMS wiring under niri).
