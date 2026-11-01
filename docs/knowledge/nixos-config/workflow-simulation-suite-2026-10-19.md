---
name: workflow-simulation-suite-2026-10-19
description: EXECUTED+ALL GREEN 2026-10-19 — 4 new permanent VM tests simulating
  per-host complex workflows (zram-heal, yoga-s2h-logic 63 asserts,
  nix-media-upgrade-pipeline, host-units-smoke) + found+fixed REAL ntfy Result
  bug; full QC green STAGED pending switch
metadata:
  node_type: memory
  type: project
  originSessionId: sess_14927617-edc0-4ba6-ad6c-5d6af61663c7
---

User asked to "simulate all complex workflows per host and evaluate error-free" (2026-10-19). Executed same day; everything staged (never committed), worktree==index verified, `nix flake check` rc=0, all 7 nixosTests + 4 host dry-builds + home-files user-unit verify GREEN.

**New permanent tests** (nixosTests, opt-in like the existing 3, CI untouched):
- `zram-heal` (tests/zram-heal.nix): heals seeded stale-initialized device AND hot_remove-missing device via systemd-zram-setup@zram0 ExecStartPre; in-use guard runs script standalone (unit restart on healthy device fails EBUSY by design).
- `yoga-s2h-logic` (tests/yoga-s2h.nix + tests/s2h-harness.sh): 63-assert state-machine harness in VM. Mount-ns bind fakes for power_supply/rtc/acpi/uptime + shims bind-mounted OVER the store systemd binaries (hook PREPENDS systemd to PATH — PATH shims can't work). Fixed since the /tmp version: hibstate needs 3 fields; parked-copy sed must run AFTER workspace bootstrap.
- `nix-media-upgrade-pipeline` (tests/nix-media-pipeline.nix): real git pull ExecStartPre as dk vs local bare origin; `system.build.nixos-rebuild` mkForce shim (upstream calls it by ABSOLUTE path — PATH shim useless); all 6 weekly-reboot guard branches; ntfy OnFailure chain.
- `host-units-smoke` (tests/host-units-smoke.nix): imports REAL hosts/latitude/default.nix over base modules with `node.specialArgs` (NOT _module.args — desktop-hyprland needs `inputs` in its imports list → config-in-imports recursion), `disabledModules` for latitude hardware-configuration (hostPlatform string vs testers-derived read-only collision), disko.enableConfig=false, boot.consoleLogLevel mkForce 7, home-manager module required (mkIf doesn't prevent option lookup). latitude wakeup oneshot + bt-agent wiring (activeness impossible adapter-less) + oomd + ryzen-tdp condition guard + is-on-ac live matrix.
- `tests/sops-stub.nix` shared: option-shape stub (path readOnly + freeform anything) so ntfy/users/sops modules eval without sops-nix; missing-secret skip branch IS the tested behavior.

**REAL BUG found+fixed** (hosts/nix-media/ntfy.nix): the ntfy-failure@ 60s settle-check used `systemctl is-failed` — but nixos-upgrade's staged `Restart=on-failure` (1h) puts failed units in "activating (auto-restart)" where is-failed is FALSE → upgrade failures NEVER notified (contradicting maintenance.nix's own comment). Fix: also probe `systemctl show -p Result --value != success` (Result keeps last attempt's outcome; transient-recovered = success stays silent). nix-media dry-build green after fix.

**VM-test lore (hard-won, reusable):**
- zram generator ExecStop RESETS the device on swapoff (BindsTo cascade) — "initialized-not-swapped" residue must be SEEDED (echo disksize / mkswap); plain swapon can never re-enable; restart the setup unit instead.
- systemd show prints booleans as yes/no (not true/false); `-p OnCalendar/Persistent` are NOT bus properties (use `systemctl cat`); Result vocab is "exit-code" not "failed"; NixOS serializes unit bools as true/false.
- Unit SCRIPT content (guards, pull lists) is invisible in `systemctl cat` — extract ExecStart path via `show -p ExecStart | grep -oP 'path=\K[^ ;]+'`.
- Fake a process for `pgrep -x`: `setsid bash -c 'printf ffmpeg > /proc/self/comm; sleep 120; true'` — echo's newline lands IN comm; bash tail-execs the last command (comm reverts); console commands' process groups get reaped (setsid); copying a binary fails (coreutils multi-call rejects argv0).
- Docker-enabled VM idles above load 2 — guard tests that must REACH later branches need fake /proc/loadavg.
- Root git on dk-owned clone needs `-c safe.directory=…` (the unit's runuser exists precisely for this).
- Host-module imports in tests need the mkHost specialArgs set: inputs/self/flakeRoot/mainUser (+ home-manager module), best via node.specialArgs.

**Validation-coverage assessment (delivered 2026-10-20 after user challenged the complexity):**
- ~9 of ~10 troubleshooting rounds were TEST-machinery quirks; exactly ONE product bug (ntfy) — a class pure reasoning misses (Restart=on-failure → activating/auto-restart makes is-failed false).
- Shimmed-but-pre-proven mechanisms (tests only log argv): s2h `systemd-run` transient units (15s recheck/3s hibernate deferral — abort-recheck variant ran in production since 2026-09-09; openlid-resuspend reuses it, but the two-window policy has NEVER run live), nixos-rebuild boot (dry-builds prove eval), real `shutdown -r +1`.
- Uncovered by tests AND mental simulation — the LIVE switch is the final gate: yoga journal grep "window 1/2"/"window 2/2" + one supervised manual `systemctl hibernate` before trusting the 2h automated path; nix-media `git -C ~dk/nixos-config status` (clone must be ff-only-able or pull fails — now at least notifies thanks to the fix).
- ntfy fix edge: a unit that fails then is manually STOPPED (not restarted clean) still has Result=exit-code → one notify — harmless/arguably correct. Transient-failure-restarted-clean = Result success → silent (the designed case holds).
- ntfy.shim hot_add id-mismatch failure branch never exercised (2-line warn+exit, low risk).

Related: [[repo-review-2026-10-19]], [[yoga-hibernate-status]], [[zcode-shell-sandbox-etc]]
