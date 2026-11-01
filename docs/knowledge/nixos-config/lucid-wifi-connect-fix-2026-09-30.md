---
name: lucid-wifi-connect-fix-2026-09-30
description: lucid wifi panel failed on saved networks — root cause iwd
  connect-failed status 1 after panel's forced pre-disconnect; fix =
  102-wifi-connect-resilience.patch STAGED; live dedupe EXECUTED; user steps
  pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c31395e4-5057-48e3-84ef-5b3b798913aa
---

User couldn't connect to known/saved wifi from the lucid panel (yoga, lucid-testing branch).

**Root cause (journal-evidenced 2026-09-30 15:39):** `WifiPanel.attemptConnect()` force-disconnected the active network before `network.connect()` (Quickshell → NM `ActivateConnection`). Under NM's **iwd backend** this disconnect→connect race made iwd fail association (`connect-failed, status: 1` on every BSS of the ESS, incl. `net.connman.iwd.Failed/Aborted`); the panel's one-shot 15s timer then showed failure and **misleadingly opened the password box for the saved network** (stored PSK was fine, `psk-flags 0`). iwd's background autoconnect recovered ~1 min later — never for `FRITZ!Box Arbeit` (autoconnect off). Repo-side causes ruled out: profiles persisted (`/etc/NetworkManager/system-connections` + `/var/lib/iwd` bind mounts verified), polkit blanket YES via `networkmanager` group, nmcli/python3 on the lucid unit's pinned PATH.

**Fix STAGED (uncommitted):** `home/lucid-patches/102-wifi-connect-resilience.patch` (WifiPanel.qml only): (1) no pre-disconnect in `attemptConnect`/`submitPassword`, (2) one silent retry via new `retryOrFail()` + `maxConnectAttempts: 2` + `connectAttempt` uiState counter (retry suppressed when `attemptedWithNewPassword` — never retry a just-typed PSK against the stored one), (3) no password box for saved networks on failure/timeout. Wired into `home/lucid.nix` patches list + REPO_OVERVIEW.md patch inventory. QC green: nix fmt, flake check, dry-build yoga, lucid-source drv REALLY BUILT, output WifiPanel.qml byte-identical to intent, qmllint parses (651→652 warnings, one benign unqualified-access). Patch-gen recipe: diff a/b copies of deployed `~/.config/quickshell/lucidbar/WifiPanel.qml` with `diff -u --label a/... --label b/...` (GNU patch -p1).

**Live EXECUTED:** deleted `FRITZ!Box 7590_2 1` profile — duplicate of `FRITZ!Box 7590_2` with an **EMPTY stored psk** (nmcli -s showed empty; could never authenticate) — keep original with real key. One profile per SSID confirmed after.

**Pending user steps:** switch (`nus`), `systemctl --user restart lucid.service` (QML reloads only on restart), click-test switching saved networks; `sudo ls -la /etc/NetworkManager/system-connections/` then `sudo rm` the dangling `home-wifi.nmconnection`/`work-wifi.nmconnection` entries (NM ENOENT-warns each boot; dir invisible to agent sandbox, needs root); post-switch proof `grep -n maxConnectAttempts ~/.config/quickshell/lucidbar/WifiPanel.qml`.

**Fallback lever if failures persist:** switch `core.networking.backend` to `wpa_supplicant` in hosts/yoga (rejected for now — keeps iwd + RoamRetryInterval=120 AX210 roaming tuning). Related: [[lucid-hardening-quickshell-flake-2026-09-30]], [[lucid-buildtime-patches-2026-09-28]].
