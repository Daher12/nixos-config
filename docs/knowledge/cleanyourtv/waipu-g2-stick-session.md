---
name: waipu-g2-stick-session
description: waipu.tv Stick (G2) debloat session 2026-10-31 — firmware refuses
  pm disable (suspend+appops works), ends with ProjEngMenu back as Home per
  owner, build toolchain path on this NixOS machine
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b55434a2-28c4-41fd-af20-e515a77f166d
---

Session on the user's own waipu.tv Stick (G2) (`SEID00DWP`, Android 14, Wi-Fi 192.168.88.x, ADB 5555), 2026-10-31. Full notes in the repo's `work/README.md`; backups in `backup/`, screenshots in `shots/` (all gitignored). Sibling device notes: `docs/devices/waipu-tv-stick.md` and `waipu-tv-box.md`.

Non-obvious facts that outlive the session:

- This firmware family refuses `pm disable-user` ("Warning! This command is illegal!") **and** `pm uninstall` for preinstalled apps; the working debloat is `pm suspend --user 0` + `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore` + `cmd appops write-settings`. Suspensions survive reboots.
- The waipu app (`de.exaring.waipu`) is the stock launcher and must stay enabled (it is also Live TV). The G2 stick had a user-installed ProjEngMenu app as default Home whose Projectivy accessibility service re-opened it over the new launcher after every boot — fix is removing that one service from `enabled_accessibility_services`, not touching the app.
- Owner's remote: Input button sends zero kernel events (hardware/firmware, not the debloat); Netflix/YouTube/waipu buttons are HID consumer usages (Home 0x0c0223, D-pad 0x0c0043-45); vendor `com.nes.tvglobalkeyhandler` launches Netflix/waipu directly so no key helper is needed for those.
- HomeKeyService (HOME_KEY_SERVICE=1) costs held-key repeats on this unit (volume steps once per press) — owner accepted the trade for power_on_home.
- Build toolchain on this NixOS machine: no Docker, no system Java — use `nix-shell -p jdk17` with `JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))`, `ANDROID_HOME=$HOME/Android/Sdk` (cmdline-tools + platforms;android-34 + build-tools;34.0.0 already installed and license-accepted). **b64push over Wi-Fi times out on this stick** — push with the adb binary (`adb push`) + `pm install -r` instead.
- The stick reboots in ~40 s and cuts ADB's base64 shell pushes under load; plain adb binary is reliable.
- **End state (owner's choice, same evening): ProjEngMenu (`com.spocky.projengmenu`) back as default Home** — the owner is used to the Projectivy-style home (the actual Projectivy Launcher is not installed; ProjEngMenu is the same dev's Projectivy-derived home and was the pre-session default). `HomeKeyService` disabled again (held-key volume repeats back; it would otherwise steal the Home key from ProjEngMenu). cleanyourtv launcher stays installed with dock/hidden-apps/`power_on_home` config intact for easy switch-back. The 19-suspension debloat is unchanged.
- **Upstream docs PR prepared (2026-10-31)**: branch `docs/waipu-stick-g2` (commit f88166e6, 4 files: new `docs/devices/waipu-tv-stick-g2.md`, cross-links in the two waipu notes, `examples/README.md` index bullet; per-TV `config.xml` deliberately excluded). Full suite passed with `CLEANYOURTV_STRICT=1` (2652 tests OK). Pushed to the owner's fork `Daher12/cleanyourtv`; the owner clicks open the PR via the Gathin23 compare URL.
- **GitHub access on this machine**: no `gh` CLI; git user is Daher12 with no push rights to `Gathin23/cleanyourtv` (fork + PR workflow required); SSH key authenticates as Daher12 and can push to their own forks; fork creation needed a manual web click (no API token).
- **Firmware reverts `adb_enabled`/`adb_wifi_enabled` settings writes at every boot** (`persist.sys.usb.config=adb`, `service.adb.tcp.port=5555`); only the on-screen Developer-options toggles are the real ADB state. Owner keeps USB debugging (5555) on deliberately.
