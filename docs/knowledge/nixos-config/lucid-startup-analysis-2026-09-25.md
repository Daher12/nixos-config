---
name: lucid-startup-analysis-2026-09-25
description: Lucid shell startup audit 2026-09-25 — ~10s boot delay root-caused
  to lucid-lock-at-boot implicit target-ordering deadlock; fix APPLIED 2026-09-26
  (staged, uncommitted) incl. persistence current_* dirs→files; QML 3.7s load is
  structural (quickshell qsintercept blocks Qt disk cache)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_408f7b81-ff4a-42d7-928f-0021e68fa237
---

2026-09-25 audit of lucid (quickshell 0.3.1) startup on yoga, measured from `journalctl --user -u lucid`, systemd monotonic unit timestamps, and `/run/user/1000/quickshell/by-id/<id>/log.log` (plain text, ms precision — the qslog binary next to it is not worth parsing). Login→bar ≈ 17s: greetd auth 23:25:09 → wayland-wm@hyprland.desktop active +2.3s → **+9.5s dead** → graphical-session.target 23:25:22 → lucid QML load 3.69s ("Launching config"→"Configuration Loaded") → bar settled ~4s after login+load.

**Deadlock root cause — FIXED 2026-09-26, staged on lucid-testing (uncommitted, dry-build yoga green):** `lucid-lock-at-boot.service` (modules/features/desktop-hyprland.nix; oneshot, WantedBy=graphical-session.target, no ordering) retries `qs ipc call lock lock` 50×0.2s waiting for the shell's IPC. systemd targets implicitly gain `After=` on every unit they Want, so the target waits for this loop while `lucid.service` (After= the target) can't start → loop always exhausts at boot, unit FAILS every autologin boot, and the intended lock-after-autologin NEVER engages. Fix applied: `Unit.After = [ "graphical-session.target" ]` on lucid-lock-at-boot AND the dormant `dms-lock-at-boot` twin (same latent bug). Units already ordering themselves after the target are skipped by the implicit complement (proven live — lucid + lucid-auto-mode are Wanted but absent from the target's After= list; battery-refresh already had it). Ordering after the sibling service instead WOULD cycle (lucid→target→lock→lucid) — the old repo comment's fear was correct for that variant only; comment + REPO_OVERVIEW.md gotcha rewritten (it previously taught the buggy no-After pattern). Post-fix the lock actually engages (~4s after login). USER must rebuild + reboot to benefit.

**Persistence bug found while applying (2026-09-26):** the "empty dirs" `~/.cache/current_{theme,wallpaper,mode}` are impermanence bind mounts — persisted in hosts/yoga/home.nix `directories` but lucid expects FILES there (that's the "Not a file" FileView spam; state unwritable). Moved to the `files` list (impermanence file bind-mounts). ~~USER MUST `sudo rmdir /persist/...` BEFORE the first switch~~ **RESOLVED 2026-09-27 evening:** user's rmdir attempt returned ENOTDIR on all three — /persist already holds proper regular files (theme=matugen, mode=dark, wallpaper path; wallpaper+mode mtimes 2026-09-27 21:01) and `~/.cache/current_theme` is a bind mount of the `@persist` file (same inode) → migration completed earlier (dirs removed + a files-based generation switched to and booted), persistence write-through confirmed live. cava + PowerProfiles warnings: user said ignore.

**QML 3.7s load is structural:** quickshell routes QML imports through its `qsintercept:` URL scheme; Qt's QML disk cache only engages for `file:` URLs; upstream `src/launch/launch.cpp` has the cache-enable block commented out ("The qml engine currently refuses to cache non file (qsintercept) paths") — still commented in master as of 2026-09-26. On-disk proof: `~/.cache/quickshell/qmlcache` holds exactly ONE .qmlc (from a manual `qs -p theme-dump.qml` run) — ~200 files/5.5MB recompile from scratch every start. Not fixable from repo config; needs upstream.

Hygiene left as-is: `/etc/security/faillock.conf` missing (one warn); a dock pin references missing `~/.local/share/winapps/icons/windows.svg`. `Lockscreen.qml:681` registers the `lock` IPC target, so the post-fix retry loop will succeed.

Diagnostics that worked: `systemctl --user show <unit> -p ActiveEnterTimestampMonotonic` for cross-unit boot timelines; `systemctl --user show graphical-session.target -p After -p Wants` exposes implicit deps; launch-shell.sh picks QSG_RHI_BACKEND (vulkan only for proprietary NVIDIA ≥555, `--explain` flag). See [[lucid-integration-plan]].
