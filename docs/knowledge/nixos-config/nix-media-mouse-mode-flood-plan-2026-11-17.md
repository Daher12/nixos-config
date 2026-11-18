---
name: nix-media-mouse-mode-flood-plan-2026-11-17
description: PLAN (ExitPlanMode denied, nothing executed) — stuck SGR
  mouse-reporting mode floods nix-media SSH sessions; precmd self-heal guard
  designed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_218f1183-2904-4772-9ff5-bfca565f6174
---

**Status:** SUPERSEDED — EXECUTED + fully validated same day, see [[nix-media-stuck-mouse-modes-2026-11-17]] (user exited plan mode manually with "execute plan" after ExitPlanMode denied ×2). Plan-mode diagnosis + intermittency validation + falsification condition retained below.

**Validation vs intermittency (user: "at times it works fine, fresh session for example"; "right now it's working somehow"; trigger may've been ox in the same session beforehand):** the per-pane-lifetime model was re-checked and HOLDS — a config bug would be deterministic (every session incl. fresh would flood); instead fresh windows are clean (new pane = modes off), the flood persists for the pane's lifetime, Ctrl+C clears only the buffered line, and "working again" = fresh window or a later clean-exit TUI resetting modes. Intermittency = the enabler (ox most likely) needs an UNGRACEFUL exit (kill/crash/SSH drop) — clean quits disable mouse properly. Falsification condition recorded: flood in a brand-new window where no TUI ever ran would reopen diagnosis. Guard is a no-op in clean panes (DECRST of already-off modes is harmless).

**Diagnosis (high confidence):**
- Garbage = SGR mouse-motion events `ESC[<35;x;yM` (35 = mode-1003 any-motion + 1006 SGR encoding — exactly crossterm's EnableMouseCapture signature). Foot pane stuck in mouse-reporting mode; foot keeps DECSET state per pane for the pane's LIFETIME, so the enabler is any mouse-capable TUI that ran in that window earlier and exited ungracefully (killed/crashed/SSH drop). Under Wayland pointer focus, hovering ANY cursed window floods it.
- User clarified: NOT using ox this occurrence; Ctrl+C "clears it" — Ctrl+C only discards the buffered line, the mode stays on.
- Repo verified CLEAN (Explore agent + my reads): hosts/nix-media/zsh-functions.zsh has zero escapes/TUI calls; repo-wide no DECSET 1000/1002/1003/1006; nix-media zsh = NixOS defaults + omz agnoster, plugins=[] (see [[media-workflow-harvest-2026-11-17]] for the wiring). `ox` (editor, mouse on by default via crossterm) and `btop` are installed on nix-media (default.nix:166-167) — plausible enablers but unconfirmed.

**Ready fix plan (2 files):**
1. Append to `hosts/nix-media/zsh-functions.zsh` (do NOT touch harvested function bodies): `_reset_mouse_modes() { printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l' }` + `autoload -Uz add-zsh-hook; add-zsh-hook precmd _reset_mouse_modes`. Precmd at every prompt = self-healing, covers all enablers; unrarall entry-reset unnecessary (precmd already cleaned before job starts).
2. Extend wiring comment in `hosts/nix-media/default.nix` (~:129) to mention the guard.
3. Execution: `git add` BOTH files (flake reads index; zsh file is staged-new — re-add after edits), `nix fmt hosts/nix-media/default.nix`, `scripts/test-suite fast nix-media`.
- Immediate user-side relief (no rebuild): `printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'` per stuck window.
- Verify live post-switch: fresh ssh, jiggle mouse at prompt → silent; `printf '\e[?1003$p\e[?1006$p'` → both `;2$y` (off). Optional root-cause hunt: clean-exit vs `kill -9` btop to find the leaker.
