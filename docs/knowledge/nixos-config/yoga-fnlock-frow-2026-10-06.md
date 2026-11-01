---
name: yoga-fnlock-frow-2026-10-06
description: yoga F-row "always media" — REAL root cause = lucid upstream BARE F1-F12 binds (firmware exonerated); fn_lock=1 = F-KEYS default (polarity MEASURED, earlier 0-advice was backwards); fix EXECUTED + QC green 2026-10-06, switch pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e621e0d7-07d2-451f-96b4-9547c07859ad
---

2026-10-06. SUPERSEDES the first EC-FnLock diagnosis in this same session. User follow-up (Fn+F ALSO gives media; Fn+Esc "does nothing"; onset = **after switching to lucid**) broke the EC theory; evdev capture settled it.

**Real root cause:** lucid's upstream defaults in `~/.config/lucid/keybinds.json` bind the BARE F1–F12 to media actions — ids `f1-mute, f2-vol-down, f3-vol-up, f4-mic-mute, f5-bright-down, f6-bright-up, f8-rfkill, f9-terminal, f10-lock, f12-calc` (category "Function keys"; no F7/F11). Kernel provably delivers real KEY_F1 → lucid eats it; XF86 keys hit the xf86-* binds → BOTH paths end in the media action, so F-row is ALWAYS media regardless of Fn/FnLock. Onset matches the lucid switch 2026-09-23. Firmware/EC/OS all exonerated: udev db applied `KEYBOARD_KEY_0d=rfkill` to event4 but NOTHING to event0 (control experiment — hwdb pipeline works, no entry matches 82TL); no keyd/kanata; repo + nixos-hardware module + git pickaxe clean.

**MEASURED polarity on 82TL (live evdev capture — trust this, not intuition):** `fn_lock=1` = **F-keys DEFAULT** (bare F1 → KEY_F1 code 59/scan 0x3b; Fn+F1 → KEY_MUTE 113/scan 0xa0). `0` = media default. My earlier "write 0 to sysfs" advice was BACKWARDS. Fn+Esc flips bit+fnlock LED in perfect sync, purely EC-level — ZERO evdev events (Fn is invisible to the OS; can only be observed via /sys poll). Bit persists across reboots.

**EXECUTED 2026-10-06 by main session after user approval. ⚠️ Status correction later that evening (a later session found `git diff --cached` EMPTY): the edits are UNSTAGED working-tree only, NOT staged — flake eval / `nix fmt` / dry-build read the git INDEX and are blind to them until `git add` is re-run.** QC green: migration jq dry-run on a live-copy → exactly 10 Function-keys binds `enabled:false`, idempotence guard rc=1; `nix fmt`; `nixos-rebuild dry-build --flake .#yoga` passes; flake eval confirms tmpfiles rule `w …fnlock/brightness - - - - 1` and bt-agent ExecStart. Edits: (a) seed jq in home/lucid.nix gains the 10 f-ids in the enabled=false list; (b) in-place migration after the ghostty→kitty block, guard `.id=="f1-mute" | (.enabled != false)` (idempotent; user re-enables in Lucid Settings survive); keep xf86-* binds; (c) tmpfiles rule in hosts/yoga/default.nix: `"w /sys/class/leds/platform::fnlock/brightness - - - - 1"` (**1**, not 0).

**Diagnostic technique (reusable):** /dev/input/event0 IS readable by agent shells (root:nogroup 0660, dk in nogroup); evtest + libinput CLI absent but `/run/current-system/sw/bin/python3` exists → passive evdev capture (setsid python, struct `'=qqHHi'` 24-byte input_event, select loop + 0.25 s sysfs LED/fn_lock poll) synced with the user pressing keys via AskUserQuestion — worked flawlessly. atkbd emits MSC_SCAN scancodes.

**Post-switch checks:** FnLk LED dark → one Fn+Esc (LED lit = F-keys default); kitty `cat -v` + F1 → `^[OP`; if binds still live, lucid didn't hot-reload keybinds.json → restart lucid AFTER closing ZCode sessions (restart kills them, see [[lucid-lightmode-icons-2026-09-26]]). Related: [[lucid-bluetooth-pairing-agent-2026-10-06]] (same session, same handoff).
