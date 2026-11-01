---
name: lucid-lock-beads-layoutchip-2026-10-08
description: Lock-screen fixes EXECUTED — 109 pooled password beads (twitch
  fix), 110 layout-chip truncation ("NO DEA" → GERMAN) — QC green, STAGED,
  switch pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c5638bcc-df2c-47e5-b65b-754f74f53b55
---

2026-10-08: executed the approved lock-screen plan (plan approved 2026-10-07 after
user reported twitching password dots + asked what "NO DEA" means).

**109-lockfield-beads.patch** (`lucidlock/LockField.qml`): root cause of the
all-dots twitch = `Repeater { model: input.text.length }` — an int model makes
Qt regenerate EVERY bead delegate per keystroke, replaying the 300 ms
`NumberAnimation on born` settle on all dots at once. Fix: constant pool
`model: 256`, `filled: index < input.text.length`, `born: filled ? 1 : 0` with
`Behavior on born` (Behaviors don't fire on initial binding eval → pre-existing
beads render settled), `visible: filled` — Qt Row does NOT lay out invisible
children (docs verified), so row width / overflow scroll `x: Math.min(0, …)` are
unchanged. Only the newest bead animates now.

**110-lock-layout-chip.patch** (`Lockscreen.qml` root): "NO DEA" = layout chip
fed by `hyprctl devices -j` `active_keymap` = `German (no dead keys)`;
`layoutShort` grabbed the parenthetical + `substring(0,6).toUpperCase()`.
Fix: parenthetical only wins when ≤4 chars (tags like "US"); else layout name →
GERMAN. Chip is intentional (shows which layout receives the password;
kb_layout = "de,us" in home/hyprland.nix:138-139). Hide-it alternative (user
may still want): `visible: false` on the chip at lucidlock/LockAuthCard.qml:277.

Workflow used (template for future patch adds): build activationPackage → grep
`lucid-source-1.10.5-local` out of `$ACT/activate` (that's the fully-patched
001–108 base) → cp to /tmp base/ + b2/ → edit b2 → `diff -u base/<file>
b2/<file>` (diff exits 1, don't chain with &&) → patch -p1 --dry-run verify →
add to lucid.nix patches list → fmt/stage/flake check/dry-build → content gate =
rebuild activationPackage, `diff -ruN` new lucid-source vs b2/ (BYTE-IDENTICAL ✓).

QC 2026-10-08: flake check 0, dry-build yoga 0, content gate byte-identical +
greps (`model: 256`, `m[1].length <= 4`), qmllint (qtdeclarative bin, NOT
qttools — no new warning categories vs base). REPO_OVERVIEW §381 prose extended
(001–106 → 109/110; 107/108 were never documented there). All STAGED with the
pre-existing 103–108 work; NEVER commit (house rule). lucidSync rsyncs on next
switch; visual test: lock (super+l), type → only newest dot animates, chip reads
GERMAN. qmllint location lore: `nixpkgs#qt6.qtdeclarative` default output
`bin/qmllint` (6.11.2; qttools has no qmllint anymore).

Related: [[lucid-german-sweep-plan-2026-10-07]], [[lucid-bar-dashboard-fixes-2026-10-07]],
[[lucid-buildtime-patches-2026-09-28]], [[plans-for-weaker-executor]]
