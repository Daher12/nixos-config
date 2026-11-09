---
name: zcode-launcher-crash-bwrap-pdeathsig-2026-11-07
description: EXECUTED 2026-11-08+QC green STAGED (switch+live verify pending) —
  zcode "crashes" from Noctalia launcher = zcode-unmax wrapper exits → bwrap
  --die-with-parent PR_SET_PDEATHSIG kills sandbox; fixed via setsid --fork +
  stderr log in home/niri.nix
metadata:
  node_type: memory
  type: project
  originSessionId: session_8592713883c8c53c2f812b6b8c48be62
---

zcode launcher "crashes" (2× tonight 23:46:44 + 23:47:03, right after the 23:45:55 logout/login) root-caused. NOT a zcode bug: no coredumps (coredumpctl empty system-wide), no segfault/OOM, instances booted fully then died externally+silently exactly when the wrapper exited (~13–19s post-launch).

**Mechanism (verified):** Noctalia launcher entry runs `zcode-unmax --no-sandbox` (`home/niri.nix:519`, `mkForce` at :572, added in fee3af7, deployed ~23:32 HM activation — why earlier launcher launches survived). That wrapper backgrounds `zcode "$@" >/dev/null 2>&1 &`, polls niri ~150×0.1s until a NEW to-edges window (app_id "zcode") appears, maximizes it into a column, and **exits**. zcode's own FHS wrapper (`/etc/profiles/per-user/dk/bin/zcode`, appimageTools wrapType2) ends `exec bwrap --die-with-parent ...` — die-with-parent ties the sandbox's lifetime to its parent: parent exits → kernel SIGKILLs bwrap (PR_SET_PDEATHSIG) and takes the sandbox down. Terminal `zcode` survives because fish (the parent) stays alive. `>/dev/null` discard is why the deaths were invisible.

**Why the wrapper exists** (comment block home/niri.nix:508-518): zcode restores saved-MAXIMIZED window state post-map and niri grants post-map maximize unconditionally, so window-rule denies can't stop it landing edge-to-edge; the wrapper trades the to-edges window for a maximized column (tile ≥ width-6 is the race guard). A pure KDL window rule CANNOT replace it.

**Fix EXECUTED 2026-11-08, QC green, STAGED (in `home/niri.nix`, not yet switched):** zcodeUnmax now launches `setsid --fork zcode "$@" >>"$log" 2>&1 &` with `$log=~/.local/state/zcode/launcher.log` (mkdir -p + 1MB truncate) instead of `>/dev/null`, plus a comment documenting the die-with-parent trap (plain setsid/nohup do NOT help — must use `--fork` so the intermediate exits before bwrap starts → pdeathsig parent = init, deterministically fires never since parent already dead before prctl). QC: `nix fmt home/niri.nix` + `git add home/niri.nix` (flake reads index) + `scripts/test-suite fast` → OK (yoga yoga-niri latitude nix-media). **Pending:** switch (user runs `nus`; house rule = ask first) then live-verify: launcher launch survives 30s+ past window-appear and the log file collects stderr. Fallback if setsid --fork misbehaves live: wrapper `wait`s on the background PID (keeps parent alive, one idle bash per session). Interim until switch: launcher-launched zcode keeps dying ~15s in; terminal launches unaffected.

Related: [[shell-strategy-converge-niri-noctalia-2026-11-07]], [[niri-rice-polish-2026-11-07]]
