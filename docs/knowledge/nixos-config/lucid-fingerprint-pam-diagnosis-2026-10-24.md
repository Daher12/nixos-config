---
name: lucid-fingerprint-pam-diagnosis-2026-10-24
description: SUPERSEDED — EXECUTED same day, see [[lucid-fingerprint-off-128-2026-10-24]];
  this file keeps the plan-mode diagnosis record (ExitPlanMode was denied here,
  re-planned+executed in the follow-up session)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5435017b-ab03-45c7-9c96-6c430a5b4ab1
---

**SUPERSEDED 2026-10-24: the fix (patch 128 fingerprint-off) is EXECUTED + QC green + STAGED — see [[lucid-fingerprint-off-128-2026-10-24]] for the live record.** Historical plan record below.

Root cause of the recurring journal noise observed in [[lucid-idle-round2-126-127-2026-10-24]] QC pass (the "pre-existing P3 observation" the user later asked about), fully diagnosed 2026-10-24 via two Explore agents (journal verbose metadata + live tree reads — plan-mode Bash for /etc lies per [[zcode-shell-sandbox-etc]]):

- **Chain:** lucid v1.20.1 (live since 2026-10-16 sweep; first error 2026-10-17 boot −2) `Lockscreen.qml:161 lockNow() → startFinger()` unconditionally starts a second `PamContext` with `configDirectory: Quickshell.shellPath("pam")`, `config: "fingerprint"` → shipped `~/.config/quickshell/pam/fingerprint` = `auth required pam_fprintd.so max-tries=1 timeout=60` (**bare module name**, bypasses /etc/pam.d).
- On NixOS libpam resolves bare names against linux-pam's own store dir (`/nix/store/…-linux-pam-1.7.2/lib/security/`) which has only stock modules — no pam_fprintd.so (fprintd never enabled in repo; `/run/current-system/sw/lib/security` lacks it too; stale fprintd-1.94.5 copies exist only as old greeter-build deps). dlopen fails → PAM code 28 `Modul ist nicht bekannt` → `onError → retryFinger()` backoff 2s·2ⁿ capped **60s**, retried the entire lock duration. Measured ≈1 error-triplet/min while locked, 2778 lines (~1389 attempts) per boot; stops at password unlock (separate PamContext on `/etc/pam.d/login`, healthy — journal shows successful "login" config sessions).
- **Hardware:** Yoga Slim 7 ProX 14ARH7 ("82TL") has NO fingerprint reader (USB/I2C: only Intel BT 8087:0032 + ELAN06FA touch). So `services.fprintd.enable` is NOT a fix (no hardware AND bare-name resolution would still fail — NixOS puts pam_fprintd.so nowhere libpam's default dir).
- In-place edits to `~/.config/quickshell/**` are futile — lucidSync rsync `--delete` from lucidPatched at every activation → must be a build-time patch.

**Plan (NOT executed — ExitPlanMode permission-denied):** patch `128-fingerprint-off.patch`, 2 hunks in `Lockscreen.qml` only: (1) `readonly property bool fingerEnabled: false` + dated comment at the fingerprint section (~L450); (2) early `return ;` on `!root.fingerEnabled` at top of `startFinger()` (~L453). `startFinger` is the sole entry point (L161 + fingerRetry timer L513); stopFinger callers L318/381 stay safe; password unlock untouched. Author against newest `/nix/store/*lucid-source-1.20.1-local` (with 126/127), `a/`+`b/` headers, `-p1`; append to `home/lucid.nix` patches list after 127 with dated comment; `git add` (index flake!); gates: real activationPackage build (`nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home.activationPackage -L` — the ONLY patch-applying gate per runbook §2 P2), marker grep `fingerEnabled` ×2 on new tree, `nix fmt home/lucid.nix`, `nix flake check` (parallel ntfy.nix statix red = foreign, leave alone). Docs: runbook SEVENTEEN→EIGHTEEN + row 128 + PR1049 note ≥129; REPO_OVERVIEW 17-patch mentions → 18 + lock-PAM line ~416 gains the second fingerprint PamContext. Hand-off: user switch → `systemctl --user restart lucid` → verify `journalctl --user -u lucid | grep -c pam_fprintd` = 0 after 2-min lock. Re-enable would need `fingerEnabled: true` AND an absolute store path in `pam/fingerprint`. Upstream candidate: probe fprintd D-Bus GetDevices before arming.

Marker lore: journal PAM dlopen lines carry SYSLOG_IDENTIFIER=quickshell but the decisive line is `quickshell.service.pam.subprocess: Starting pam session for user "dk" with config "fingerprint" in dir "/home/dk/.config/quickshell/pam"` — custom configDirectory hides the service from /etc/pam.d entirely.
