---
name: lucid-lockscreen-dots-layout-chip-2026-10-07
description: Lock-screen fixes PLANNED + brief handed to executor 2026-10-07,
  NOT executed — twitchy password dots (QML Repeater INT model regenerates ALL
  delegates) + "NO DEA" = layout chip slicing "German (no dead keys)" to 6
  chars; patch 109/110 designs, pool-safety fact, base-tree recipe inside
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c5638bcc-df2c-47e5-b65b-754f74f53b55
---

2026-10-07 evening, user reported two lucid lock-screen issues. Root causes verified via Explore agents against upstream lucid v1.10.5 (flake pin 09820bb; pristine store `16wvsfscpbmqcx9qfav8g0039pw3206s-source`; live `~/.config/quickshell` byte-identical except known 002/107 translation lines). Plan delivered verbatim via ExitPlanMode (rejected by UI), then user: "approved, now halt while i switch manually to the execution agent" → HALTED, nothing executed/staged; plan text = the handoff brief ([[plans-for-weaker-executor]] instance #15). Outcome of executor run UNKNOWN.

**Root causes:**
1. **Dots twitch per keystroke**: `lucidlock/LockField.qml:196-235` — beads are `Repeater { model: input.text.length }`. A QML Repeater with an INT model regenerates EVERY delegate on model change (no incremental insert), so all dots replay the 300 ms `NumberAnimation on born` settle (caret-line→dot morph). (Overflow slide `Behavior on x` is by-design, not the complaint; caret blink/x unrelated.)
2. **"NO DEA"** = lock-screen keyboard-layout chip, `Lockscreen.qml:66-73` `layoutShort`: 400 ms `hyprctl devices -j` poll (kbProc) → `active_keymap` = `German (no dead keys)` → regex takes parenthetical → `.substring(0,6).toUpperCase()` → "NO DEA". Chip visible is gated on `Lockscreen.focused` (why it appears only while typing). Indicator is genuinely useful: user runs `kb_layout "de,us"` + `kb_variant "nodeadkeys,"` (`home/hyprland.nix:138-139`). ⚠️ The SAME poll feeds capsLock — hiding the chip must NOT remove the poll.

**Planned patches (append after staged 001–108; `base/`+`b2/` diff prefixes like 107):**
- `109-lockfield-beads.patch` (`lucidlock/LockField.qml`): pool the beads — `model: 256`; delegate gets `property bool filled: index < input.text.length`, `property real born: filled ? 1 : 0`, `visible: bead.filled`; `Behavior on born` (300 ms bezier) replaces `NumberAnimation on born`. Load-bearing VERIFIED fact: Qt Row positioner does NOT lay out invisible/zero-size children (Qt 6 docs) → row width + overflow-scroll `x: Math.min(0, beadsClip.width - beads.width)` behave unchanged; Behaviors don't fire on initial binding evaluation → pre-existing beads render settled; backspace flips filled false → instant vanish, no replay.
- `110-lock-layout-chip.patch` (tree-ROOT `Lockscreen.qml`, not lucidlock/): `layoutShort` uses the parenthetical only when ≤ 4 chars (tag like "US"), else the layout's first word → shows **GERMAN** / **US**. AskUserQuestion (fix vs hide vs leave) went UNANSWERED → recommended fix-label chosen; one-line alternative if user prefers hiding: chip `visible:` at `lucidlock/LockAuthCard.qml:277` → `false`.
- Base-tree recipe: `ACT=$(nix build --no-link --print-out-paths .#nixosConfigurations.yoga.config.home-manager.users.dk.home.activationPackage)` → `LUCIDSRC=$(grep -o '/nix/store/[a-z0-9]*-lucid-source-1.10.5-local' "$ACT/activate" | head -1)`; sanity greps (`Passwort` present = 107 applied; `model: input.text.length` present = block untouched); cp tree → /tmp/{base,b2}, edit b2, `diff -u base/… b2/…`; append both to the `patches` list in `home/lucid.nix`; `git add` staging-only; QC = `nix flake check` + `nixos-rebuild dry-build --flake .#yoga` + byte-diff rebuilt lucid-source tree vs b2 + REPO_OVERVIEW patch-enumeration check. NO switch — user does it (visual test: super+L then type; only newest dot animates, chip reads GERMAN).

Related: [[lucid-buildtime-patches-2026-09-28]], [[lucid-bar-dashboard-fixes-2026-10-07]], [[lucid-german-touchups-lockclock-2026-10-07]]
