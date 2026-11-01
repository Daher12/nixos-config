---
name: ask-dont-infer-system-state
description: Don't present inferences about system state or user actions as fact
  — journals show WHAT booted, not WHY; ask the user
metadata:
  node_type: memory
  type: feedback
  originSessionId: sess_79448bac-47dc-459a-b1be-ca7564cc7440
---

During the 2026-09-16 DMCUB incident I wrote gen 138 "was apparently never set as boot default". Wrong: 138 WAS the default and boot-looped; the user had manually booted gen 137 to troubleshoot. User: "ask if you dont have the exact information man".

**Why:** Journals/kernel cmdlines prove which store path booted, but never *why* that path booted (menu pick vs default vs rollback vs boot loop). In incidents the user holds key facts; confident wrong guesses cost trust and misdirect debugging.

**How to apply:** Present journal-derived facts as facts, and ask directly for anything about user actions/intent (boot-menu selections, commands run, what they saw on screen). Second instance 2026-09-19 (jellyfin): I asserted from registry tag dates that the server had been on 10.x and that 12.1 was "the breaking release with the manual process" — journals proved 12.0 had run since ~09-11 (likely the user's own manual upgrade), and 12.1 turned out to be a routine bugfix release. Verify which version an external article/release actually refers to — and what the host actually ran — before acting on upgrade narratives. Related: [[user-communication-style]], [[yoga-dmcub-firmware-regression]], [[jellyfin-pin-nix-media]].
