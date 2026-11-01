---
name: quickshell-icon-provider-crash-2026-10-10
description: Lucid restart crash-loop 2026-10-10 root-caused to quickshell
  IconImageProvider thread race (lock-free provider hitting thread-unsafe QIcon
  from two threads); QMutex patch plan APPROVED, halted for executor
metadata:
  node_type: memory
  type: project
  originSessionId: sess_9ac2496f-3575-46a6-90cd-a24697c1ced7
---

## Diagnosis (from ~/.cache/quickshell/crashes/{9gj8y0womt,raj8v0womt,z4j8s0womt}, all 2026-10-10 13:31)

Quickshell crash-restart loop right after the day's rebuild + lucid restart (~13:20): PIDs 398251 → 398449 → 398649 each died SECONDS after start; 4th attempt (398659) survived. Two signatures, ONE root cause:

- Main thread SIGSEGV inside QSvgIconEngine (`tryLoad` / `detach_helper`): `HyprlandToplevel::updateFromObject` → dock `clientsData` binding (luciddocks/Dock.qml, fed from Hyprland.toplevels) → `appListModel.append` → Repeater creates DockItem delegate → its `IconImage` is **synchronous** (quickshell's IconImage widget defaults `asynchronous: false`) → `IconImageProvider::requestPixmap` on the MAIN thread.
- Reader-thread SIGABRT (`__cxa_pure_virtual` in `QPlatformPixmap::fromFile`, from `QQuickPixmapReader::processJob`): async icon loads — the patch-111 sites (SysTray.qml 109/672, Workspaces badgeIcon, NotifAvatar.qml:30) — call the SAME provider from Qt's single pixmap-reader thread.

quickshell 0.3.1 (pinned rev 5d5d498) `IconImageProvider::requestPixmap` (src/core/iconimageprovider.cpp) has **NO locking**; `QIcon::fromTheme`/`QIcon::pixmap` mutate Qt's global icon-theme cache (QIconLoaderEngine / QSvgIconEngine shared data) which is not thread-safe → both threads during the startup icon storm corrupt shared state. Upstream: issues #1007, #1028, #1056, #1079 (same signatures, all OPEN); master verified still lock-free → no bump fixes it. Patch 111 plausibly widened the window (per-site `backer.sourceSize` = more distinct provider cache keys at startup) but the race predates it.

Sync (main-thread) IconImage sites in lucid: luciddocks/DockItem.qml:140 (the crash entrant), StackPopup.qml:152, Switcher.qml:649+765, LauncherList.qml:594, lucidprefs/BarModuleCard.qml:378.

Crash-forensics facts: `report.txt` = readable version/build/env/stacktrace + Log Tail (the diagnosis source — journalctl/systemctl are BLOCKED in plan-mode sandbox); `log.qslog.log` is BINARY (`grep -a` works for timestamps). Dump folders kept as upstream evidence (~350 KB, ephemeral ~/.cache).

## APPROVED fix — handed to executor 2026-10-10, NOT executed

1. New `quickshell-patches/201-iconprovider-thread-safety.patch`: `#include <QMutex>`/`<QMutexLocker>`, file-scope `static QMutex` + `QMutexLocker` at top of `requestPixmap` (source fetched verbatim at pinned rev; `requestString` builds only a URL — no lock needed). 2xx numbering distinguishes from the lucid 1xx layer.
2. flake.nix overlay: `overrideAttrs` (append patch) **BEFORE** `.withModules [qt6.qt5compat]` — withModules does NOT chain (see [[lucid-v120-minimal-bump-2026-10-09]]), must be the single final call.
3. `git add` the new patch file (flake reads the index; re-add after every later edit).
4. QC: `nix build .#nixosConfigurations.yoga.pkgs.quickshell` (~4 min source build), `nix fmt flake.nix` (explicit file), `nix flake check`, `nixos-rebuild dry-build --flake .#yoga`.
5. Post-switch: `systemctl --user restart lucid` (wrapper/env changes are NEVER picked up by config reload); stress = 3–4 lucid restarts + window open/close right after each start; check no NEW crashes/ entries; dock/tray/badge icons still sharp (mutex = timing only, no pixel change). Drop the patch when upstream fixes #1028/#1056/#1079.

Rejected alternative: lucid patch adding `asynchronous: true` to the 6 sync sites — icon pop-in, and any future sync site at a lucid bump silently reintroduces the race. Related: [[lucid-v120-polish-plan-2026-10-10]], [[lucid-buildtime-patches-2026-09-28]].
