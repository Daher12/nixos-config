---
name: niri-cursor-size-32-2026-11-07
description: niri cursor block REQUIRED for 32px — no-block default 24 clobbers
  XCURSOR_SIZE; nixpkgs niri 26.04 wants xcursor-theme/xcursor-size (theme/size
  keys REJECTED)
metadata:
  node_type: memory
  type: project
  originSessionId: session_2fde239691df1f5f0b4d1b592d9753af
---

EXECUTED 2026-11-07, QC green (test-suite fast yoga-niri + `niri validate` on the generated config), STAGED on niri-testing.

User report after the niri switch: pointer shrank 32→~24px. Cause: `home/niri.nix` had **no `cursor` block**, so niri fell back to its built-in default (24px) — and niri **exports `XCURSOR_SIZE`/`XCURSOR_THEME` to spawned apps from its own config**, clobbering the 32/Posy session env that `home/theme.nix` sets. Home-manager sessionVariables alone can never win against niri.

Fix: `cursor { xcursor-theme "Posy_Cursor_Black"; xcursor-size 32 }` in `home/niri.nix` KDL.

**Lore (both verified against the installed binary, not the wiki):**
- nixpkgs niri **26.04 rejects** the new `cursor { theme / size }` keys ("unexpected node") — the rename is NOT in this build; must use legacy `xcursor-theme` / `xcursor-size`. Validate any future key names with `niri validate -c` on a throwaway config; the wiki renders ahead of nixpkgs.
- The greeter (`noctalia-greeter` NixOS module in `modules/features/desktop-niri.nix`) already had `cursor.size = 32` — only the session side was missing, which is why the greeter looked right and the session didn't.

Related: [[shell-strategy-converge-niri-noctalia-2026-11-07]]
