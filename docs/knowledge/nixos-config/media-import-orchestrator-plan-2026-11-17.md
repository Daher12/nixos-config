---
name: media-import-orchestrator-plan-2026-11-17
description: PLAN (v2, user-revised, ExitPlanMode denied — nothing executed) —
  one-command `media-import` orchestrator for nix-media with staging lane
  /mnt/storage/downloads/incoming; user decisions locked
metadata:
  node_type: memory
  type: project
  originSessionId: sess_28fc01e0-fe23-4023-a791-04d1ae871a35
---

Successor to the harvested manual pipeline ([[media-workflow-harvest-2026-11-17]]). User asked to smooth/automate the workflow; decisions locked via AskUserQuestion 2026-11-17, plan v1 REJECTED by user feedback, v2 drafted, ExitPlanMode DENIED — NOTHING EXECUTED.

**User decisions (locked):**
- **One-command interactive orchestrator** — NO timer, NO unattended moves (human confirms mnamer matches; rationale = Silo hand-matching history). *arr stack explicitly rejected as overkill.
- **Confirm-gated prune** of rar sets/empty dirs (never silent deletes).
- **Staging lane one level deeper** (user feedback on v1): `/mnt/storage/downloads/incoming/` is the ONLY path the pipeline reads/writes/prunes — because downloads top level also holds unrelated files and old rar archives that must never be touched (v1's whole-folder `*.rar` prune would have eaten old batches' rars). Top level = manual parking zone; links.txt stays there.

**v2 design (the plan):**
- `hosts/nix-media/zsh-functions.zsh` deltas: `aria` += `mkdir -p` + `-d …/incoming` (kills CWD trap); `unrarall` += password probe (`unrar t -p-` per root; prompt only if any fails — CRC failures also fail ⇒ never worse than always-prompt). Verbatim constraint was move-only; reviewed post-harvest edits are fine.
- `hosts/nix-media/default.nix`: `features.mnamer.paths.downloads = "/mnt/storage/downloads/incoming"` (existing option; `raw` subcommand keeps ad-hoc paths) + writeShellApplication `media-import` whose bash text is just `exec env ZSH_FUNCTIONS=… zsh ${mediaImportZsh} "$@"` (repo .zsh files via writeText/readFile — escaping-free, single source of truth; shellcheck only sees the shim).
- NEW `hosts/nix-media/media-import.zsh` — 5 stages, all inside incoming/: ① foreground aria2c (same flags as aria; skip if no links.txt / --no-download) ② unrarall at lane top + per first-level subdir holding rars (folder-shaped releases; tee stdout, stdin stays tty for password read) ③ mnamer-tools import-test → [y/N] → import ④ prune (only after successful import, [y/N]; rars + empty dirs under lane only; non-empty dirs survive ⇒ unmatched media waits in place) ⑤ `ntfy-send` summary (extracted/imported/leftover; degrade to log if absent). Flags: --no-download, --test, --help.
- Infra facts grounding it: `ntfy-send` wrapper already in systemPackages (hosts/nix-media/ntfy.nix, best-effort contract); hardened systemd timer patterns exist (maintenance.nix) if automation is ever wanted; mnamer module assertion downloads≠movies/shows still holds with the lane path.

Verification designed: git-add new files, nix fmt, `zsh -n` via nix shell, `nix eval --option eval-cache false` (zshrc text + systemPackages + mnamer settings), --help smoke from built toplevel, test-suite fast nix-media, VM battery SKIP (text-only). Docs: REPO_OVERVIEW + memory records + export-zcode-memory.
