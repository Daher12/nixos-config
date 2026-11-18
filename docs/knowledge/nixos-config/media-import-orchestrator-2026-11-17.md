---
name: media-import-orchestrator-2026-11-17
description: media-import one-command pipeline orchestrator for nix-media
  EXECUTED (staging lane incoming/, confirm-gated import+prune, ntfy summary, no
  timer)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_28fc01e0-fe23-4023-a791-04d1ae871a35
---

`media-import` orchestrator — EXECUTED 2026-11-17, `test-suite fast nix-media` OK, staged UNCOMMITTED. Supersedes the manual three-command flow of [[media-workflow-harvest-2026-11-17]] / [[nix-media-media-import-workflow]] (those functions still exist standalone; orchestrator reuses them).

**Design decisions (user-picked via AskUserQuestion):** ONE interactive command, human at both decision points (password, match confirm) — NO systemd timer, NO unattended moves (user explicitly chose orchestrator-only over timer variants). Confirm-gated prune. NOT an *arr stack.

**Staging lane invariant:** `/mnt/storage/downloads/incoming/` is the ONLY path the pipeline reads/writes/prunes (user feedback on rejected v1 plan: downloads top level holds unrelated files + old rars). `mediaLane` let-constant in `hosts/nix-media/default.nix` mirrored as `LANE` in `media-import.zsh` and hardcoded in `aria` — change all three together. `features.mnamer.paths.downloads` retargeted to the lane (mnamer-tools import*/raw; raw keeps manual full control). Old habit unchanged: `aria` still reads links.txt from downloads TOP level, downloads INTO the lane.

**Stages** (hosts/nix-media/media-import.zsh): ① download — foreground aria2c, lane links.txt first, legacy top-level links.txt fallback, same flags as aria minus --daemon; ② extract — unrarall at lane top + each first-level subdir containing rars (folder releases); ③ import — count media-mask files → `mnamer-tools import-test` → confirm → import (decline/zero = skip); ④ prune — only after a real import, lists `*.rar` under lane + empty-dir delete, confirm-gated; ⑤ ntfy summary (imported/unmatched). Flags: `--no-download`, `--test` (dry: no import/prune), `--help`. Stage rc via plain-call + explicit `$?` check (NOT `||` — tested context would suppress the stages' internal err_return; zsh ERR_EXIT suppression lore).

**Wiring:** bash `writeShellApplication` wrapper (shellcheck does the packaging) execs `env ZSH_FUNCTIONS=<store-copy> zsh media-import.zsh` — zsh logic stays escaping-free in the repo file; runtimeInputs zsh/unrar/aria2/findutils/coreutils, mnamer-tools+ntfy-send via ambient PATH. Functions file shared: same `zsh-functions.zsh` sourced by orchestrator AND loaded via `programs.zsh.interactiveShellInit`.

**Harvest deltas in zsh-functions.zsh** (verbatim constraint intentionally dropped once repo-owned): aria += `mkdir -p` lane + `-d lane` (CWD trap dead); unrarall password probe — tests each root `unrar t -p- -y -- file </dev/null`, prompts only when one fails (zero-keypress plain batches; `-p-` not in unrar's short help — the stdin redirect backstops any interpretation, worst case = old always-prompt; probe misfire on CRC-broken sets = same fallback); prompt moved to stderr (`print -u2 -n`) so orchestrator stdout redirection can't buffer-delay it. Orchestrator deliberately does NOT tee unrarall output (prompt-latency + pipe-race traps; summary counts derive from mnamer inventory deltas instead — deviation from approved plan text, noted in session).

QC ROUND 2026-11-17 (user-prompted "slow downloads?" review) — 3 fixes landed, gate re-green:
1. **In-flight guard** (real hazard, found during the review): aria2c `falloc` PREALLOCATES full-size files → a half-downloaded multipart set looks complete to unrarall → truncated media → mnamer imports broken files. stage_extract now aborts while any `$LANE/**/*.aria2` control file exists (confirm-gated default-N override for stale ones). Slow-download pattern that motivates it: `aria` daemon → later `media-import --no-download`.
2. **unrarall no-archives demote**: its `return 1` on "No matching archives" (interactive contract) under stage err_return = "stage 2 failed" on a perfectly normal rar-less lane (bare .mkv downloads) → `unrarall || print note` at lane top + subdirs.
3. **Prune lock**: DID_IMPORT=1 only after `mnamer-tools import` exits 0 (failed import no longer unlocks the delete confirm; partial imports prune on a later successful run).

Verified lore: unrar 7.23 accepts `--` end-of-switches (missing file → exit 10 = probe-safe); `print -u2 -n` prompt = stderr, no newline (pipe-safe); real built wrapper (`toplevel/sw/bin/media-import --help`) exercises env ZSH_FUNCTIONS plumbing OK. KNOWN INTERACTION (open, not fixed): weekly-reboot Sun 07:30 checks ffmpeg/load/uptime only — a daemon `aria` download spanning Sunday gets killed (resumable via control files); one-liner pgrep guard in maintenance.nix if user wants it. Foreground `media-import` = SSH-session-coupled (tmux NOT installed on nix-media; long runs → daemon pattern instead).

SESSION/USAGE MODEL (explained to user 2026-11-17 after "keep ssh active the whole time?"): NO — only the interactive variant couples the session, and only for stage 1 (the long part). Canonical slow/batch pattern: `aria` (daemon, survives logout) → hours later `media-import --no-download` (fast interactive tail: extract+confirms in minutes; in-flight guard makes any-time running safe). Session-drop mid-`media-import` = benign: download resumes via `.aria2` control files, nothing destructive half-done (prune locked to successful import, confirms default No), already-imported items stay. tmux OFFERED (one-line `environment.systemPackages` addition so full `media-import` incl. download can be detached/reattached, prompts wait) — user has NOT decided; mosh is installed but is link-robustness, not a detach mechanism.

PENDING user-side (same as harvest): switch on nix-media → first real `media-import` run → then strip `~/.zshrc`. NOTE: mnamer path change is part of the same switch; running `mnamer-tools import` from an OLD generation still scans the top level — do the switch first.
