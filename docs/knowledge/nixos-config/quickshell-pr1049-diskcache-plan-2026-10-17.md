---
name: quickshell-pr1049-diskcache-plan-2026-10-17
description: PLAN (not executed) 2026-10-17 — port quickshell PR #1049 QML disk cache as engine patch 202 + lucid pragma patch 122; ExitPlanMode DENIED after accidental zcode exit; all facts + gates gathered
metadata:
  node_type: memory
  type: project
  originSessionId: sess_8ab5e781-9d5d-4680-865e-1ef4e25e2657
---

User opted in 2026-10-17 to the former "Tier 3" item (the appendix text was from a prior session's plan — NOT in any repo file). Full plan was built and submitted; **ExitPlanMode was DENIED ("Permission denied") after the user accidentally exited zcode — plan ready to re-run verbatim, nothing executed.**

## The feature (2 pieces, one feature)
- PR #1049 (quickshell-mirror/quickshell, OPEN/unmerged, 1 commit `e26a7c0`, ~+340/−130, 9 files: `src/core/{generation,qsintercept,rootwrapper,toolsupport}.{cpp,hpp}`, `src/launch/launch.cpp`, changelog): vfs mirror → `file://` QML URLs → Qt disk cache engages. DMS measured: warm launch 1.28s→0.77s, −40MB RSS. This IS the fix for our known "qsintercept blocks Qt cache / 3.7s QML load" structural finding ([[lucid-startup-analysis-2026-09-25]]).
- **Pragma-gated per config**: engine patch alone does nothing; needs `//@ pragma DiskCache` as line 1 of the config's root QML. Lucid root = `shell.qml` (confirmed home/lucid.nix:768, synced to ~/.config/quickshell/shell.qml). Greeter has no pragma → unaffected.
- Piece 1: `quickshell-patches/202-vfs-mirror-qml-disk-cache.patch` appended at flake.nix:168 (`qs.unwrapped` patches list, next to 201 — **no textual overlap**: 201 touches only `src/core/iconimageprovider.cpp`, not among the 9).
- Piece 2: `home/lucid-patches/122-diskcache-pragma.patch` (one line in shell.qml), appended to lucid patches list home/lucid.nix:49-69. NO existing lucid patch touches shell.qml.

## Key facts pinned
- quickshell pin 4f508be500dea6e5732cc3d50382a0048b17e7b1 (0.3.2); PR branch ~Sep 22 is OLDER than pin, master force-pushed Oct 6 in between → cherry-pick onto 4f508be in /var/tmp (NOT /tmp — ENOSPC seen in agent shell), export `git diff 4f508be -- src/` (drops changelog hunk), round-trip `git apply --check` incl. on top of 201. Halt if conflicts need semantics (esp. toolsupport.cpp).
- /tmp near-full again (2GB tmpfs gotcha).
- Runtime verify: `systemctl --user set-environment QT_LOGGING_RULES=qt.qml.diskcache=true` + restart lucid; 1st restart builds cache (~4.5s one-time), 2nd restart SILENT (pre-patch symptom: "File has to be a local file." errors ×1000). Unset env after.
- Costs: mirror in /run/user/1000 tmpfs (rebuild once/session), ~/.cache/quickshell grows to 1200+ files, we own the port across every quickshell pin bump (same tax as 201).
- Revert = drop 202 from flake.nix list AND 122 from lucid.nix list together (stock engine + stray pragma untested).
- QC: git add new patches immediately (index gotcha), `nix fmt flake.nix home/lucid.nix` explicit, flake check (retry lock race), `nixos-rebuild dry-build --flake .#yoga` (compiles quickshell ~4-5min), `strings $out/bin/qs | grep -ci qt5compat` ≥1, `qs --version` = 0.3.2, runbook markers 12/12.
- Docs to sync: LUCID_RUNBOOK patch-count ELEVEN→TWELVE + Appendix A row for 122 (`grep -c 'pragma DiskCache' "$SRC/shell.qml"` ≥1) + engine-layer note near Appendix B; REPO_OVERVIEW line 385 extend for 202, **line 143 is STALE** (still describes abandoned withModules approach — fix in same change); line 44 tree comment still accurate.
- Discovered: runbook Appendix A covers LUCID patches only; quickshell ENGINE patch layer (201) documented only in flake.nix comment + REPO_OVERVIEW:385; runbook line 467 also recommends the old withModules approach (stale).
- No pin bump, no minQuickshell change, ~/.cache/quickshell already persisted on yoga.

Related: [[quickshell-icon-race-fix-2026-10-10]], [[plans-for-weaker-executor]], [[parallel-index-work]] (big staged update-sweep + audit-round2 work sits in the index — add-only).
