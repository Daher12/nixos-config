---
name: nix-media-stuck-mouse-modes-2026-11-17
description: SSH-to-nix-media garbage flood = foot pane stuck in SGR mouse modes
  1003+1006; precmd reset guard EXECUTED in zsh-functions.zsh
metadata:
  node_type: memory
  type: project
  originSessionId: sess_218f1183-2904-4772-9ff5-bfca565f6174
---

Incident 2026-11-17: SSH sessions to nix-media flooded `zsh: command not found: 35;53;37M35;52;37M…` on cursor movement, during and long after unrarall/unrar runs.

**Diagnosis (verified):** `35;x;yM` = SGR mouse motion with Cb=35 → modes 1003 (any-motion) + 1006 (SGR) left ON in the **foot pane**. foot keeps DECSET state for the pane's lifetime, so any mouse-capable TUI that exits ungracefully in that window (ox — mouse on by default via crossterm EnableMouseCapture; btop; nvim) curses it until something resets. Repo ruled out as emitter (grep: no DECSET 1000/1002/1003/1006 anywhere; unrarall/aria clean; nix-media zsh is NixOS defaults). Intermittent = the ungraceful-exit trigger; fresh windows clean. Ctrl+C only discards the buffered line, not the mode. Under Wayland pointer focus the flood hits on hover, not just focus.

**Remedy EXECUTED+FULLY VALIDATED 2026-11-17, fast green, STAGED (switch pending, never committed):** `_reset_mouse_modes()` precmd hook appended to `hosts/nix-media/zsh-functions.zsh` (printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'), so every interactive prompt self-heals. Immediate user-side remedy until switch: `printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'` per stuck window.

**Validation round (all green, ran on the REAL generated artifact):** (1) worktree==index, no parallel-session drift; (2) `zsh -n` OK; (3) non-interactive source (media-import path, ZSH_FUNCTIONS per [[media-workflow-harvest-2026-11-17]]'s orchestrator) registers but never fires — inert by design; (4) direct call emits exactly the four sequences; (5) prompt-loop firing proven (piped interactive zsh emitted them before its prompt); (6) built the deployed `/etc/zshrc` via `nix build .#nixosConfigurations.nix-media.config.environment.etc."zshrc".source` — functions at lines 50–182, hook registered at 184, omz sourced at 210; (7) ran that generated file end-to-end: `_reset_mouse_modes` SURVIVES oh-my-zsh init (omz appends its own hooks via add-zsh-hook, never resets precmd_functions) — final chain: `_defer_async_git_register _reset_mouse_modes _zsh_autosuggest_start _omz_async_request omz_termsupport_precmd _zsh_highlight_main__precmd_hook`; unrarall/aria defined. Remaining: live wiggle test after user switch.

**Tooling lore:** `nix eval --raw .#nixosConfigurations.nix-media.config.programs.zsh.interactiveShellInit` FAILS with "store path … has a name longer than 211 characters" — a nix eval-printing quirk on the huge composed string (omz/zoxide/syntax-highlighting drv refs; flaky via eval cache), NOT a config defect. Route around it: build `config.environment.etc."zshrc".source` and grep the file. Also: sandbox shells lack `zsh` on PATH — use a nixpkgs#zsh build path or /run/current-system/sw/bin/zsh.

**How to apply:** any future "escape garbage executes as commands" report → decode the trailing byte and button code first (`M`=SGR mouse, `~`=other), suspect stuck pane state over config bugs; fix with a precmd reset, not one-off printf lore. To prove a shell-hook fix, run the GENERATED /etc/zshrc end-to-end (ZDOTDIR tempdir trick) rather than trusting eval or asserting omz behavior.
