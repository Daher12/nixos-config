---
name: hyprland-lucid-retirement-plan-2026-11-14
description: PLAN approved via AskUserQuestion but ExitPlanMode DENIED — retire
  hyprland/lucid/DMS from main, promote niri to .#yoga; full removal map + audit
  findings + locked user decisions
metadata:
  node_type: memory
  type: project
  originSessionId: sess_364713f2-914e-4aa7-8050-b0e8d602f0dd
---

2026-11-14 session: user decided niri is the daily driver, GNOME stays backup; hyprland+lucid(+DMS/quickshell tooling) to be archived and removed from main. Full repo audit ran (3 Explore agents) — verdict healthy, no eval-breaking bugs. Plan finalized, **ExitPlanMode DENIED → NOTHING executed** (plan text is in the session; this file preserves the decisions + load-bearing facts).

**User decisions (locked via AskUserQuestion):**
1. `yoga` attr = niri (profiles `["laptop" "desktop-niri"]`), **drop `yoga-niri`**; final attrs: yoga, yoga-gnome, latitude, nix-media.
2. **Commit + push authorized** for this work (logical commits + fresh archive branch + push to origin) — explicit exception to the never-commit rule.
3. Include lean batch: dead ghostty options, dead `features.filesystem.mountOptions`, uid pin dedup into profiles/laptop.nix, nix-media kvm-intel/tmpfs/pulseaudio restates, README "two Windows guests"→one.
4. Local `dux-shell` branch: keep as-is (local-only, rebases will hurt but acceptable).

**Load-bearing couplings (each breaks eval / niri if missed):**
- `home/noctalia.nix:27` pulls GoogleSansFlex.ttf + OFL from `inputs.lucid` → **vendor TTF into home/assets/ FIRST**, then drop the lucid input.
- `desktop.hyprland.monitors` is read by niri.nix:16 + battery-refresh.nix:15 (assertion 251-256), set in hosts/yoga/home.nix:317 for EVERY attr → relocate as `desktop.monitors` (defined in battery-refresh.nix), don't delete.
- Assertion cross-refs into `features.desktop-hyprland.enable` in desktop-gnome.nix:50 + desktop-niri.nix:82 must be edited in lockstep; `modules/features/default.nix:6` import (currently drags dank-greeter/dux-shell upstream modules into EVERY host eval); `home/default.nix` imports dms/hyprland/lucid + dconf gate L41.

**Backup status (user question "did we?")**: `archive/lucid`@3388242 exists+pushed but is a 2026-11-01 snapshot — main's newer hyprland.nix (+134 DMS-IPC) + desktop-hyprland.nix (+118) NOT in it → plan cuts fresh `archive/hyprland-lucid` at the last pre-removal commit.

**Planned commit sequence**: (1) land staged autologin work [[niri-greetd-autologin-2026-11-14]]; (2) vendor font; (3) archive branch + push; (4) removal+promotion (delete home/{hyprland,lucid,dms}.nix + lucid-patches/german/themes + dms-themes + desktop-hyprland module/profile + quickshell-patches/ + LUCID_RUNBOOK.md + docs/upstream-prs/001; drop inputs quickshell/dank-greeter/lucid/dux-shell + second overlay stage; prune persistence entries, terminal.nix lucid-glass/opacity gates, theme.nix lucid branches, battery-refresh hyprlandDaemon → selector niri:else gnome); (5) scripts/docs sync (test-suite ALL_HOSTS, update-safe pins+guard, README/REPO_OVERVIEW/AGENTS); (6) lean batch.

**Audit findings**: fastfetch double-installed on yoga attr (dies with lucid); README missing yoga-niri entirely + stale "niri-testing branch"/greeter "1.6.2" comments in flake.nix; standing debt = latitude/nix-media sops rekey (retired admin key) + 2 dead latitude wifi secrets (user-side); VM gate recommendation = skip battery, live switch is the proof.

**Why:** the whole repo architecture (attrs, scripts, CI lists, docs) still assumes lucid-on-hyprland as `.#yoga`.
**How to apply:** when re-planning or executing, follow the commit order above; after commit 4 ANY rebuild of `.#yoga` switches the machine to niri (user aware). See [[branch-promotion-exec-2026-11-11]] for branch topology.
