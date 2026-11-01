---
name: parallel-index-work
description: user/other sessions stage work into the same git index MID-session
  — re-check git status before attributing staged changes; leave their work
  alone except mechanical lint-gate fixes, which must be reported
metadata:
  node_type: memory
  type: feedback
  source_session: sess_b41281f9-e28d-4664-bbb0-64d8cea10e82
  originSessionId: sess_b41281f9-e28d-4664-bbb0-64d8cea10e82
---

During the 2026-09-17 latitude/disko session the git index changed twice mid-work:
the linux-firmware pin (flake.nix/flake.lock) was already staged at a "clean"
session start, then a whole Hyprland feature (home/hyprland.nix,
modules/features/desktop-hyprland.nix, yoga tweaks, profiles, update-safe rework)
appeared staged while QC was running. None of it mine.

**Why:** "git status clean at session start" goes stale within minutes on this
repo — the user runs parallel agent sessions and stages their own work. Assuming
sole ownership of the index leads to wrong conclusions (nearly attributed the
firmware pin to a phantom cause) and QC runs against a moving target.

**How to apply:** when `git status` shows staged changes I didn't make, inspect
them (`git diff --cached`) and treat them as the user's in-flight work: never
unstage/revert/commit them; re-run flake check/dry-build once after MY last edit
and state in the report which combined index state was validated. Exception that
proved fine: a mechanical fix to their staged code required by the lint gate
(statix `inherit (firmwarePinPkgs) linux-firmware;` rewrite) is acceptable if
behavior-identical and explicitly reported. Second occurrence same day: a
parallel session modified REPO_OVERVIEW.md between my Read and my Edit → Edit
failed "File has been modified since read"; on shared doc files late in a
session, expect this and just re-read the target section, verify my earlier
content is unchanged, then edit. Related: [[latitude-disko-opencode]].

**2026-09-22 escalation — branch-per-agent:** the user now deliberately runs
parallel agent sessions on SEPARATE BRANCHES (a caelestia agent owns
`caelestia-testing`; my session built `dms-caelestia-look`). Their staged WIP
(a profile flag flip + REPO_OVERVIEW edit) appeared in the shared main
worktree mid-session. Working pattern that preserved everything:
build/QC/commit my sibling branch in a detached `git worktree` (a worktree
has its own index, so flake ops and staging there never touch the main
worktree), then `git switch -c <their-branch>` in the main worktree —
staged changes ride along and stay staged-uncommitted, exactly as the other
agent left them. Leave the main worktree checked out on THEIR branch so they
continue seamlessly, and flag stale references in their docs (branch renamed
under them) in the report rather than editing their WIP.

**2026-09-22 late refinement:** the main-worktree checkout CHANGES HANDS
between sessions — by end of day it sat on `dms-caelestia-look` (mine), not
the caelestia agent's branch, and their session had committed 5fb56d6 on
`caelestia-testing`. Never trust a remembered "X is checked out": run
`git branch --show-current` + `git status` at the start of every turn that
touches branches or commits. Also: a stale branch pointer that another
session recreated at the same commit is fine to reset/rebuild (`--force`
worktree + reset) as long as it has no unique commits — check
`git log <branch> --not <base>` first.

**2026-09-23 — branches vanish between sessions; user issues META-RULEs:**
caelestia-testing existed at exploration time and was DELETED by execution
time (`git show caelestia-testing` → invalid object) — branch existence is as
untrustworthy as checkout state; re-verify both before relying on them. Same
session the user issued an explicit META-RULE ("IMPORTANT: WORK ONLY IN THE
lucid-testing branch (META-RULE)") hard-scoping all edits and rebuilds to my
worktree (/home/dk/nixos-config-lucid) while the main worktree sat on
noctalia-testing — another session's line AND the live system's source.
Treat a user META-RULE as a hard session constraint: route every file edit,
rebuild flake path, and verification through the designated worktree; never
touch the main checkout or sibling branches unless asked.

**2026-09-22 latest — shared MEMORY files are contended too:** a parallel
session edited caelestia-integration.md mid-session; my Edit failed
"file modified" and their rewrite had REPLACED two of my sections (the
confirmed click root cause vanished from the file). After any Edit-conflict
on a shared memory/doc file, re-read AND diff for LOST content of mine —
restore what disappeared, don't just add new text. Same round confirmed the
separation pattern: the other session had folded my staged work into their
commit on a shared branch (99adf78); recovery = worktree rebuild from base +
selective re-application, then move the shared branch pointer (see
caelestia-integration.md separation paragraph). User mandate behind all
this: exactly SIX branches (main, dms-testing, dms-caelestia-look,
caelestia-testing, archive/pre-squash-2026-09-19, backup-palette), one
workstream each — do not create branches without instruction. The user
explicitly reprimanded the flow ("you should've acted in the dms branch as
instructed") when one agent's pivot landed on the shared experiment branch
(99adf78): misplaced work is the discovering agent's to relocate onto the
right branch immediately — staying silent about branch placement reads as
endorsement.
