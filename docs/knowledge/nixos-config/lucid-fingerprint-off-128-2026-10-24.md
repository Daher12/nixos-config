---
name: lucid-fingerprint-off-128-2026-10-24
description: EXECUTED — root-caused the "Modul ist nicht bekannt" PAM spam (lock
  screen's second fingerprint PamContext, no reader/no fprintd) + patch 128
  fingerprint-off authored, QC green, STAGED; pending switch + lucid restart
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5435017b-ab03-45c7-9c96-6c430a5b4ab1
---

Diagnosis + fix EXECUTED 2026-10-24 (rides the big staged batch from [[lucid-idle-round2-126-127-2026-10-24]] and [[update-sweep-2026-10-24]]).

**Root cause (forensically confirmed):** the recurring journal error `pam_fprintd.so … "Modul ist nicht bekannt"` (PAM code 28) is lucid upstream's SECOND lock-screen PamContext: `Lockscreen.qml` `lockNow()` → `startFinger()` → `PamContext { configDirectory: Quickshell.shellPath("pam"); config: "fingerprint" }` → the file lucid itself ships at `~/.config/quickshell/pam/fingerprint` = `auth required pam_fprintd.so max-tries=1 timeout=60` — a BARE module name that libpam resolves against linux-pam's compiled-in store dir (stock modules only; fprintd is nowhere in the closure, no `security.pam` config in the repo, `/etc/pam.d` untouched). Host has NO reader (Yoga Slim 7 ProX 14ARH7: USB/I2C = Intel BT + ELAN touchscreen only). onError → `retryFinger()` exponential backoff capped at 60s → one error triplet per locked minute, ~1400 attempts/boot since 2026-10-17 04:01 (first v1.20.1 boot; cadence windows mapped exactly to locked periods). Password PamContext (`/etc/pam.d/login`, gnome-keyring wired) is separate and fine. NOT a timer — the retry loop lives in Lockscreen.qml.

**Fix — patch 128 `128-fingerprint-off.patch`:** `readonly property bool fingerEnabled: false` + early return at top of `startFinger()` (only entry point: lockNow + fingerRetry timer). 2 hunks, Lockscreen.qml only (113's hunks disjoint). Re-enable needs ALL of: flag true + services.fprintd + reader hardware + absolute store path in pam/fingerprint (bare name NEVER resolves on NixOS — even `services.fprintd.enable` alone wouldn't fix the dlopen because quickshell's configDirectory bypasses /etc/pam.d).

**QC all green:** patch dry-run OK; real activation build exit 0, 128 applied with NO offset/fuzz (the offsets in the log belong to pre-existing 117/118 hunks); output tree `0lgisxj8…-lucid-source-1.20.1-local` has exactly 2 `fingerEnabled` markers, byte-identical to authored work tree; stateFiles + quickshell gates rendered ok; nix fmt + flake check exit 0 on the combined (parallel-session) index. Docs synced: LUCID_RUNBOOK (EIGHTEEN, row 128, PR1049 pragma patch now **≥129**), REPO_OVERVIEW (18-patch layer, lock-PAM line notes the second PamContext, pins table).

**Gotchas:** (1) `grep -oE '/nix/store/...-lucid-source'` on build.log matches the `.drv` path — find the real output tree by grepping marker across `ls -dt /nix/store/*lucid-source*`. (2) The `pam/fingerprint` file is part of the rsynced lucid tree — hand-editing ~/.config/quickshell is futile (lucidSync --delete converges every activation). (3) fprintd store paths seen on disk (`igi2lm…`/`y4gpp…`) are stale deps of old dms-shell greeter builds, not in current-system.

**Pending:** user switch (rides staged batch) → `systemctl --user restart lucid` (shell outlives switches) → verify: lock ≥2 min → `journalctl --user -u lucid --since <restart> | grep -c pam_fprintd` = 0; password unlock still works. Optional follow-up: upstream lucid issue (probe fprintd D-Bus GetDevices before arming the fingerprint context).
