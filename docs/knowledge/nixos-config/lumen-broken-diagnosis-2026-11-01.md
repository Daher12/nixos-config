---
name: lumen-broken-diagnosis-2026-11-01
description: Lumen (lucid 1.20.5.5 file manager) dead = wrapper missing
  qt6.qtmultimedia; lensd crash-loop = no GI_TYPELIB_PATH; revert+fix plan
  built, ExitPlanMode DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: session_31ac84d18943e98b694b302d493813a9
---

Post-bump Lumen failure diagnosed 2026-11-01 (plan mode; ExitPlanMode DENIED — plan delivered in chat, NOTHING executed). Supersedes the "pending smoke" of [[update-sweep-2026-10-31]]: its Lumen smoke row was never actually verified.

**Root causes (evidence-backed):**
1. Lumen never opens: re-wrapped quickshell (flake.nix overlay, commit 3620529) folds qtwebengine+qtimageformats but NOT `qt6.qtmultimedia`. `lucidlumen/PreviewPane.qml:1` imports QtMultimedia; unresolvable QML import kills the whole config → `qs -p lumen.qml` exits ~0.5s. Upstream install.sh:126 `PKG_REQUIRED` includes qt6-multimedia. Fix = add `final.qt6.qtmultimedia` to wrapper buildInputs (flake.nix:219-223).
2. Lens daemon lensd.py crash-loops 1×/s ("Namespace GdkPixbuf not available", 2149 in ~5min): GI_TYPELIB_PATH set nowhere in repo; typelib lives in gdk-pixbuf store path. Fix (user APPROVED) = `environment.sessionVariables.GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" [gdk-pixbuf]` in modules/features/desktop-hyprland.nix (~line 265, next to python3.withPackages).
3. SUPER+E = lucid keybinds.json `files` bind (NOT a Hyprland bind; SUPER+SHIFT+E in home/hyprland.nix is untouched nautilus). Commit 3620529 added: one-way migration nautilus→lumen (home/lucid.nix:675-688) + registrar loop `lumen/lens --default` claiming inode/directory via xdg-mime (690-706). Live state: keybinds migrated, xdg-mime default = lucid.lumen.desktop.

**Plan:** replace forward migration with reverse migration guarded on the literal cmd `$HOME/.config/quickshell/lucidlumen/lumen` (identical in upstream seed support/hypr/keybinds.json:19 — one guard converges migrated files AND fresh seeds); delete registrar loop (keep existing .desktop files so Lumen stays launcher-testable); keep chrono.json stateFiles entry (stateFilesChecked eval gate) + qtwebengine deps; docs sync (LUCID_RUNBOOK ~24/415/504/593, REPO_OVERVIEW:148); live-state relief (jq flip, xdg-mime→org.gnome.Nautilus.desktop, `systemctl --user restart lucid`, pkill lens.qml). User chose: fix Lens too, SKIP VM battery.

**Lore:**
- Detached qs instances (`qs -p … -n -d`) log ONLY to `/run/user/1000/quickshell/by-id/*/log.log` — journald shows NOTHING. Runbook failure-playbook needs this pointer.
- ~/.config/mimeapps.list is a read-only HM store symlink; xdg-mime runtime claims land elsewhere (~/.local/share/applications/).
- SendMessage to subagents is BLOCKED in plan mode ("Plan mode only allows read-only tools") — spawn a fresh Explore agent instead of continuing one.
- Lucid migrations are one-way by design (guard on old value); reverse migrations must match BOTH the migrated value and the upstream seed value to converge fresh installs.
