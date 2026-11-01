---
name: lucid-cleanup-plan-2026-09-27
description: Lucid cleanup plan 2026-09-27 — user-picked track + decisions (DMS
  apparatus REMOVE keeping greeter; kitty consolidation); delivered as TEXT, NOT
  executed; verified git topology + deferred infra-debt list
metadata:
  node_type: memory
  type: project
  originSessionId: sess_6db0e0af-2a76-468a-9fe7-8ea7b97c7f26
---

2026-09-27 planning session over the whole repo ("what's next once lucid settles"). User picked the "Lucid cleanup & polish" track (over land&merge / infra debt / do-nothing) and made two decisions via AskUserQuestion: (1) DMS rollback apparatus = REMOVE, keep greeter; (2) terminal = consolidate on KITTY. Full plan delivered as the final text message (ExitPlanMode REJECTED — see [[plans-for-weaker-executor]]); NOTHING executed or committed. Continues [[lucid-integration-plan]]; kitty verdict finalizes [[kitty-vs-ghostty-evaluation]].

**DMS removal keep-list (load-bearing):** the flake overlay keeps `nixpkgs-unstable` + `inherit (unstable) dms-greeter quickshell` — lucid RUNS on pkgs.quickshell and the greeter on pkgs.dms-greeter, so the "DMS overlay" is not wholesale deletable. Keep dank-greeter input/module/programs.dms-greeter block, /var/cache/dms-greeter persistence, `.config/DankMaterialShell` persistence (greeter themes from its settings.json; live value currentThemeName=dynamic → colors come from synced matugen, so home/hyprland.nix DMS theme JSONs ~312-478 ARE deletable). Remove: dms-plugin-registry input+import, dms-shell overrideAttrs (flake.nix 111-124), dmsLockAtBoot + dmsCaelestiaSeed + dms options + dms config block + dms-lock-at-boot unit + dankshell PAM (desktop-hyprland.nix), assertion 271 → `!autoLogin || lucid.enable`; drop .local/state+.cache/DankMaterialShell persistence, keep .config one. Rollback = rebuild dms-caelestia-look@4b2f965 (ancestor of lucid-testing; another worktree may hold staged WIP — no branch deletion).

**Kitty consolidation mechanics (the gotchas):** the keybinds.json seed only fires when the file is ABSENT → F9 needs jq `.cmd)="kitty"` in the seed PLUS a live-migration jq for the already-deployed file. Dock.qml patch is marker-guarded and already stamps `ghostty -e` → remove the swap from the guarded set + add an UNGUARDED idempotent `sed 's/ghostty -e /kitty -e /'`. matugen `[templates.kitty]` → ~/.config/kitty/matugen-colors.conf (verify upstream template filename first: `nix eval --raw … xdg.configFile."matugen/templates".source` + ls that store path). terminal.nix: ghostty.enable default false; kitty `themeFile = mkIf (!lucid) "Nord"` + `extraConfig` include (mutually exclusive); seed `${pkgs.kitty-themes}/share/kitty-themes/Nord.conf` fallback so kitty never includes a missing file before the first matugen run.

**Dedups (byte-proven: home-files baseline diff must stay EMPTY):** theme.nix gains `options.desktop.theme.{gtkDark,gtkLight,iconDark,iconLight}` (defaults = current names) replacing its let-bindings + lucid.nix:86-92 mirrors; single `lucidPath` binding for the duplicated PATH string (lucid.nix ~518/563). lock-at-boot twin dedup is MOOT (dms twin gets deleted).

**Doc drift:** README:52 + ~66-67 still say DMS for yoga; README:191 CI "Sundays" → Saturdays (bump.yml cron `0 2 * * 6`); REPO_OVERVIEW locked-inputs sentence omits `lucid`.

**Suggested commit split:** 1) dedups, 2) DMS removal, 3) kitty + docs.

**Git topology (verified 2026-09-27):** lucid-testing = 14 commits ahead of main (6a90bac), pure fast-forward, zero conflicts, but NO origin branch — all lucid work exists only locally. noctalia-testing holds 2 unique commits (ebd8d8d+d85a786); stale stash stranded on deleted caelestia-testing; merge-to-main remains the recommended first step (user deferred it in favor of this track).

**Deferred infra-debt track (presented, user did not pick):** sops latitude+nix-media encrypted to RETIRED admin key (current operator can't edit; fold in dead-wifi-PSK drop + Grafana secret_key plaintext at hosts/nix-media/monitoring.nix:242); Jellyfin scheduled backups (only one auto zip since 2026-02-02, :latest, 12.0 precedent); latitude partlabel relabel unverified on live machine; update-safe never commits flake.lock while CI auto-commits weekly → future `git pull --ff-only` breakage.

**Why:** The plan is approved-in-content and handed off, not executed — its migration gotchas (seed-only-when-absent, marker-guarded patches, overlay keep-list) and the verified topology/debt facts are invisible from the repo without redoing the three-agent analysis.

**How to apply:** If the user reports the cleanup as executed (or hands the plan to an executor), check the result against this keep-list and the migration mechanics first; the deferred-debt list is the standing answer for future "what's next" questions.
