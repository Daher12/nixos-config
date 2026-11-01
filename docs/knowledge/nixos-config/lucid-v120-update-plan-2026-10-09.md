---
name: lucid-v120-update-plan-2026-10-09
description: Lucid v1.20 "Lucid 2" bump — plan APPROVED + handed to executor
  2026-10-09, NOT executed; minimal layer (only patch 001 survives, 12 dropped
  incl. German), all new feature deps, settings.lua wired; upstream rewrite
  absorbed 103/105/109
metadata:
  node_type: memory
  type: project
  originSessionId: sess_da69ad97-f08d-47ad-a187-bc85c62d291c
---

2026-10-09: lucid v1.20 bump planned (tag `e662954f73a39275f214923bb4dab6c85b3800ba`,
2026-10-08, "Lucid 2" — full Material You Expressive rewrite of every surface on a
new `lucidui/` control kit; ~150 MB less RAM; idle bar no longer redraws). Plan =
LUCID_RUNBOOK §2 P0–P7 + v1.20 delta layer, built from upstream fetches
(changelog/release/docs/install.sh at the tag). ExitPlanMode rejected with
"approved, now halt and let me manually switch to the execution agent" → plan
text = deliverable, repo untouched at handoff.

**User decisions (locked via AskUserQuestion):**
1. MINIMAL LAYER iteration 1: keep ONLY `001-nixos-paths.patch` (re-expressed on
   the redesigned dock); DROP 002/003/101–110 (delete files + `patches =` entries;
   git history preserves). User's custom answer NARROWED my "minimal" option —
   German 002/107 also dropped, so English UI BY DESIGN until a follow-up round;
   afterwards user evaluates per-patch rewrite vs settings-migration (P7
   follow-up table: 102 wifi flow, 104 per-module look, 105 UI tile removal, 108
   clock-app 24h, 110 chip, 003/106 bar arrangement, 101 four sub-fixes, 002/107
   German re-translation with new-string list).
2. ALL new feature deps: hyprsunset, qrencode, inotify-tools, smartmontools,
   udisks2, sshfs, sound-theme-freedesktop, fastfetch, xdg-terminal-exec
   (+pipewire-audio only if pw bits missing).
3. Deploy + REQUIRE `modules.settings` + `modules.lucid-look` (pcall AFTER our own
   config blocks so Nix wins); `plugins.lua` deployed but NEVER required (it
   builds hypr-dynamic-cursors at login); no autostart module (as before).

**Upstream v1.20 facts (fetched, not yet repo-verified):**
- Absorbed our patches: 103 (disk card LVM/LUKS + btrfs dedupe = Ciro Rivera
  #27), 105 (control-centre tiles user-arrangeable), 109 (upstream password
  beads "melt into dots"). Possibly settings-replaceable: 104 (per-module look
  options), 003/106 (bar module arrangement from Settings).
- install.sh state-file excludes UNCHANGED (same 11 files) → stateFiles eval
  gate expected green; keybinds.json still seeded only if absent; installer uses
  tar not rsync; seed() keeps existing non-empty state.
- New install duties our rsync deploy must replicate: `assets/fonts/GoogleSansFlex.ttf`
  + OFL → `~/.local/share/fonts/lucid` + fc-cache (else whole look falls back to
  default font); sounds via `support/sounds/build-sounds.py` (check prebuilt vs
  on-demand; may stay inert iteration 1); `support/hypr/modules/{settings,lucid-look,plugins}.lua`;
  4 keybinds via guarded jq migration: SUPER+ESC `qs ipc call session toggle`,
  CTRL+ALT+TAB/SHIFT+TAB `switcher next|prev`, SUPER+M logout (hyprshutdown else
  `hyprctl dispatch 'hl.dsp.exit()'`); matugen templates now follow all palettes
  (our locally-authored config.toml needs template-set diff).
- NO quickshell floor stated (0.3.1 + `minQuickshell` unchanged); Hyprland floor
  **0.55.6** (P0 check, ours is 0.55.x); SDDM theme steps IRRELEVANT (dank-greeter).

**Plan deltas over runbook P0–P7:** P0 reference prebuild (build activationPackage
at OLD pin, extract the 1.10.5 13-patch lucid-source store tree → /tmp
reference-old — deployed tree may lag, switch status after 6050cf8 unknown) +
Hyprland version check; P1 locked rev MUST equal the tag commit else STOP (no-ref
input tracks default branch); P3 drop 12 patches + hand-repair 001 + qmllint
(qtdeclarative); P4 deployment deltas; P5 shrunk content gate (001 markers +
dropped-patch ABSENCE greps + attribution diff shows ONLY 001 hunks); P6 QC +
docs sync (runbook §1 inventory→1 patch, Appendix A/B, "Last verified",
REPO_OVERVIEW); P7 relay + follow-up evaluation table.

**Repo state at handoff:** patches 103–110 COMMITTED in 6050cf8 (older memory
index lines saying "STAGED" are stale); staged = docs only (AGENTS.md,
LUCID_RUNBOOK.md, REPO_OVERVIEW.md); HEAD 78d47e4.

Related: [[lucid-runbook-2026-10-08]], [[plans-for-weaker-executor]],
[[lucid-lock-beads-layoutchip-2026-10-08]], [[lucid-bar-dashboard-fixes-2026-10-07]]
