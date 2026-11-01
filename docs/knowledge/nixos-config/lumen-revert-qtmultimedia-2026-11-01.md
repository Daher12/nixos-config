---
name: lumen-revert-qtmultimedia-2026-11-01
description: EXECUTED+QC green STAGED — Lumen revert to nautilus (SUPER+E live
  already), root cause = wrapper missing qt6.qtmultimedia
  (fixed+strings-proven), lensd GdkPixbuf crash-loop fixed via GI_TYPELIB_PATH;
  pending user switch + smoke
metadata:
  node_type: memory
  type: project
  originSessionId: session_31ac84d18943e98b694b302d493813a9
---

Executed 2026-11-01 (plan approved via ExitPlanMode). All changes STAGED, `test-suite fast` green (yoga latitude nix-media), nothing committed.

**Root cause (Lumen):** the flake overlay's quickshell wrapper gained `qt6.qtwebengine`+`qt6.qtimageformats` in the 2026-10-31 lucid 1.20.5.5 bump but skipped `qt6.qtmultimedia` — upstream install.sh `PKG_REQUIRED` lists it too. `lucidlumen/PreviewPane.qml:1` imports `QtMultimedia` at top level → the WHOLE `lumen.qml` config fails, every launch died in ~0.5 s. Fixed: `final.qt6.qtmultimedia` in wrapper `buildInputs` (flake.nix); built `.#nixosConfigurations.yoga.pkgs.quickshell` and strings-proved qtmultimedia qml+plugins paths baked (4 refs, matching webengine).

**Key lore:** detached `qs -p <config>.qml` instances (Lumen/Lens) log ONLY to `/run/user/<uid>/quickshell/by-id/<id>/log.log` — NEVER journald. LUCID_RUNBOOK §5 row + REPO_OVERVIEW updated with this (the old row's `journalctl -u lucid` advice was blind to it).

**Shortcut anatomy:** SUPER+E = lucid's `keybinds.json` `files` bind (lucid.nix lucidSync migration), NOT Hyprland (SUPER+SHIFT+E, repo-owned, never moved). Reverse migration guarded on `.cmd == "$HOME/.config/quickshell/lucidlumen/lumen"` — that literal is BOTH what the old forward migration wrote AND what upstream's fresh seed ships, so one guard converges yoga/latitude + fresh installs; Lucid-Settings-edited cmds survive. Registrar loop (`lumen/lens --default`) deleted; the once-written `lucid.{lumen,lens}.desktop` entries stay (launcher access for smoke-testing Lumen post-fix).

**mimeapps gotcha:** `xdg-mime query default inode/directory → lucid.lumen.desktop` was a mimeinfo.cache HEURISTIC — no mimeapps.list anywhere had an entry. Durable fix = hand-pin `inode/directory=org.gnome.Nautilus.desktop` in `~/.local/share/applications/mimeapps.list` (PERSISTED on yoga, hosts/yoga/home.nix:172). A repo-side `xdg.mimeApps` pin was considered and NOT done (beyond approved scope) — candidate if the default ever drifts again.

**Lens (2nd defect, fixed same round):** `lensd.py` crash-looped 1/s (`Namespace GdkPixbuf not available`, 2149 in ~5 min; stops when the lens qs instance exits). Fix: `environment.sessionVariables.GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" [ pkgs.gdk-pixbuf ]` in desktop-hyprland.nix — gi searches env path THEN its built-in dir, so Gio/GObject resolution is unaffected. Reaches lensd at next login/launch post-switch.

**Live relief done same day (no switch needed):** keybinds.json `files` → nautilus (jq), mimeapps pin, `systemctl --user restart lucid` (new instance wsp1o2ztnt, log clean), SUPER+E live again. Lens instance had already exited on its own at 10:15.

**Pending:** user runs `sudo nixos-rebuild switch --flake .#yoga` then smoke: ① SUPER+E → Nautilus, ② launcher → Lumen opens with preview pane, ③ Lens opens, lensd stays quiet. If Lumen proves out, restoring it on SUPER+E = one forward-migration block + registrar loop (git history has both). [[zcode-shell-sandbox-etc]] didn't block this round — systemctl --user / jq / xdg-mime all worked from agent shells.
