---
name: yoga-wifi-nopassword-incident-2026-10-24
description: DIAGNOSED + re-express-102 plan ready (ExitPlanMode DENIED, NOTHING
  executed) — wifi "Kein Passwort gespeichert" error after resume = Lenovo EC
  ideapad rfkill glitch wedged iwd (instant connect-failed status:1, zero auth
  frames), panel mistranslates NM NoSecrets; password/persistence exonerated;
  plan collides on patch number 128 with fingerprint plan
metadata:
  node_type: memory
  type: project
  originSessionId: sess_441e8c61-0929-4e8c-840b-67dc308f4137
---

Wifi incident 2026-10-24 ~22:49–22:52 CEST on yoga (user: "couldn't reconnect, 'no password saved' even after typing password, wifi toggle fixed it"). Fully diagnosed via two Explore agents (journal + live lucid tree). Related: [[lucid-wifi-connect-fix-2026-09-30]], [[yoga-iwd-band-flap-fix]].

## Root cause (two layers)

1. **Trigger:** minutes after s2idle resume (22:43 resume → 22:49 wedge; identical self-healed copy at 12:06), the Lenovo EC `ideapad_wlan` platform rfkill (idx 0, only tracked rfkill is phy0=idx 2 — iwd logs `rfkill id 0 not found in a RFKILL_OP_CHANGE`) glitched → local deauth reason 3 + interface down (`CMD_TRIGGER_SCAN: Network is down (100)`). Radio returned ~2s later but iwd 3.12 stayed wedged 3 min: every connect (autoconnect AND manual AND both password submissions 22:51:46-53) failed instantly `connect-failed, status: 1` with ZERO kernel auth frames. User's wifi off/on = rfkill power-cycle + firmware re-init → connected in 4s. Wrong-password signature is different (auth+assoc succeed, then 4-way timeout) — password exonerated. Intel AX210/iwlwifi. No clean kernel-side fix; `ideapad_laptop` is load-bearing (conservation_mode).
2. **Panel lie (the fixable bug):** lucid `lucidbar/WifiPanel.qml:682` maps NM `NoSecrets` device-state reason → "Kein Passwort für dieses Netzwerk gespeichert." and reopens the password box for ANY secured-network failure; `:509` failReason even overrides "Falsches Passwort." after a fresh submission. Old **patch 102** (force-disconnect removal + 1 silent retry + no password box for saved networks) was **deliberately dropped in the v1.20 rewrite** (d5d7845); runbook watch-items (LUCID_RUNBOOK.md ~112, ~400, ~483 + REPO_OVERVIEW.md:412) predicted this exact regression and prescribe "re-express 102". Forced `root.activeNetwork.disconnect()` is back at live WifiPanel.qml ~744-745 (attemptConnect) and ~761-762 (submitPassword). Old patch recoverable: `git show d5d7845^:home/lucid-patches/102-wifi-connect-resilience.patch`.

## Exonerated
- Credentials: iwd psk profile present, autoconnected all week; no duplicate SSIDs (FRITZ!Box 7590_2 is a genuinely different SSID). /var/lib/iwd + NM system-connections both persisted (hosts/yoga/default.nix:358,361). Impermanence NOT implicated.
- Stack: NM (active, D-Bus) driving iwd is the designed stack (modules/core/networking.nix backend="iwd"); TLP has no WIFI_PWR keys set (defaults only).

## Plan (NOT executed — ExitPlanMode permission-denied; AskUserQuestion about scope also unanswered → defaulted to "patch only", auto radio-cycle heal declined for now, add if wedge recurs)
Re-express 102 as new patch: remove forced disconnects, `maxConnectAttempts: 2`/`retryOrFail()` wired into onConnectionFailed + 15s timeout timer, saved-network failure → generic "Verbindung fehlgeschlagen." + no auto password box (`showPasswordInput: isSecured && !savedNet`), escape hatch = 2nd manual click offers password box (genuine PSK change). Register in home/lucid.nix patch list, docs sync (runbook + REPO_OVERVIEW watch-items), gates: git add → nix fmt → flake check → dry-build yoga → user switch + `systemctl --user restart lucid` + marker grep in live tree. Known limitation: retry alone won't heal a multi-minute driver wedge — the off/on toggle (panel runs `nmcli device connect` 1.2s after re-enable, WifiPanel.qml:886-905) remains the manual out.

⚠️ **Patch number collision:** this plan proposes **128**, but parallel-session [[lucid-fingerprint-pam-diagnosis-2026-10-24]] also plans a **patch 128** (fingerprint-off). Whoever executes second must renumber (wifi or fingerprint → 129). PR1049 pragma patch was already ≥128 per [[lucid-idle-round2-126-127-2026-10-24]] — numbering pressure is real.

**RESOLVED 2026-10-24 (collision):** fingerprint-off EXECUTED first and took **128** ([[lucid-fingerprint-off-128-2026-10-24]]) — this wifi plan's patch, whenever executed, is **129**. PR1049 pragma patch then ≥130.
