---
name: lucid-patch-layer-plan-2026-09-28
description: 2026-09-28 lucid integration audit + approved plan (activation-sed
  patches → build-time .patch files + fork bugfixes + stateFiles assert) —
  EXECUTED same day on user command, see lucid-buildtime-patches-2026-09-28;
  audit verdict + fork facts retained here
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a55ce154-6f64-44f7-8a66-775c0a4d5c04
---

2026-09-28 full audit of the lucid integration (user: "best practices? stable/clean/future-proof? maybe a fork?"). **Verdict: architecture sound** — upstream is Arch-only (installer dies without /etc/arch-release), has NO flake/.nix/modules, moves ~3 commits/day, no i18n, self-mutating state, envtool rewrites gtk ini+gsettings, Idle page owns the `hypridle` unit; our rsync-into-writable-dir + seed-if-absent + store-symlinks-read-only + HM units is the standard bridge. The ONE below-best-practice piece: ~7 sed patches inside `home.activation.lucidSync` fail SILENTLY on upstream drift. Pin `09820bb` = v1.10.5 = upstream HEAD 2026-09-22; stateFiles verified 1:1 against install.sh tar excludes.

**Decisions** (AskUserQuestion unanswered → best judgment; user later text-approved): Option A in-repo build-time `.patch` files — own GitHub fork REJECTED (2nd repo + push ritual, deployment machinery needed anyway); adopt fork bugfix set. Rejected fixes: logout (both variants — setup is uwsm-only, upstream `uwsm stop || hyprctl dispatch exit` already correct), Text/TextInput rendering primitives (entangled), envtool `/usr/lib64` (our 001 covers NixOS), keybinds exit chain (bind disabled), BarPill stableHoverSurface, all of immanonymouse (cosmetics+webapps).

**Plan (handed off as guardrails brief to the weaker executor; NOTHING executed):**
- Phase 1: generate patches by diffing pinned-rev clone vs live `~/.config/quickshell` (validated: live = upstream + exactly the documented seds — byte-checked Dock.qml/resolve-icons.sh/envtool.py/Mpris.qml). Exactly 10 patched files → `home/lucid-patches/{001-nixos-paths,002-german-ui,003-mpris-hide}.patch`; 001 also folds joeangi's `.desktop` precedence (move `"$HOME/.local/share/applications"` to FRONT — upstream already scans it, just 2nd).
- Phase 2: `lucidPatched` stdenv.mkDerivation { src = lucidSrc; patches; dontConfigure/dontBuild/dontFixup; cp -r . $out; } in the let-block; repoint LUCID_SRC + xdg.configFile sources; DELETE the sed block (~lines 335–465, incl. the now-dead ghostty→kitty tree sed — upstream v1.10.5 ships `kitty -e`; keybinds.json jq migration STAYS, it's runtime state).
- Phase 3: `101-fork-bugfixes.patch` = Notifs.qml SVG fix + lucidosd/Osd.qml + System.qml 3 brightness hunks (DROP surfaceLayered @@-539) + Mpris.qml static text (all fa1261c@joeangi) + Loc.qml geolocation fix (**1f90b01@joegieee, NOT 3a1b793** — fork-report agent misattributed, verified against real .patch).
- Phase 4: stateFiles drift assert — **home-manager has NO `assertions` option** (404 + empty search) → module-level lazy `assert cfg.enable -> (lists match) || builtins.throw msg` between `in` and `{`; awww-daemon ExecStart → `"${pkgs.awww}/bin/awww-daemon"` (in unstable nixpkgs 0.12.0, NOT stable, but resolves in this flake's pkgs — already a system package); rm the stale persisted-worktree sentence REPO_OVERVIEW.md:388.
- QC: flake check + 3 dry-builds + V5 store-tree-vs-live diff (extract path via `sed -n 's/^.*LUCID_SRC="\([^"]*\)".*/\1/p'` on activationPackage/activate — a `grep -o '[a-z0-9]*-lucid-source'` TRUNCATES the version suffix) + home-files symlink targets.

Fork facts: none of joegieee/joeangi/immanonymouse do Nix work or upstream PRs; joeangi ⊃ joegieee (same 5 SHAs + fa1261c); fa1261c = 13 files, Dock.qml = 2 separable hunks (@@-721 logout guard / @@-1299 precedence), System.qml = 4; 3a1b793 routes logout/brightness via NEW support/lucid/{logout,brightness}.sh helpers (conflicts with fa1261c inline).

User does post-execution: rebuild/switch, logout/in, sanity list, commit. Builds on the staged state from [[lucid-cleanup-dms-removal-2026-09-27]]; brief format per [[plans-for-weaker-executor]].
