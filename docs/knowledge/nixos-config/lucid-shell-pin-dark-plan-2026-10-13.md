---
name: lucid-shell-pin-dark-plan-2026-10-13
description: Shell-pinned-dark + apps-auto changeset PLAN APPROVED 2026-10-13,
  handed to executor manually, NOT executed here
metadata:
  node_type: memory
  type: project
  originSessionId: sess_139a6d73-f9af-4d49-91e9-295d19df6a9a
---

Changeset planned 2026-10-13 (evening): **shell stays dark permanently, apps keep auto light/dark (08:00/19:00), GTK4 = accepted libadwaita-by-design**. Plan approved verbally after unanswered AskUserQuestion (defaults used: reset-dark-at-every-login; stock Adwaita for GTK4). User then said "approved now halt" — handed to the execution agent manually, NOT executed in that session.

Key design facts (all verified against pin e662954):
- Upstream `apply-theme.sh` supports `--apps-only` (renders kitty/gtk colors.css/starship/templates, leaves `~/.cache/quickshell/matugen.json` = shell palette untouched) and `--shell-only`. Neither writes `current_mode`. This makes the decoupling 100% repo-side in `home/lucid.nix` — no new patch, runbook untouched.
- Timer `lucidAutoMode`: replace `set-mode.sh` call with `apply-theme.sh --apps-only <theme> <mode>` (derived themes matugen/pywal/colour keep legacy coupled `set-mode.sh` fallback); wallpaper-repair leg passes SHELL mode from `current_mode`, not clock mode; keep gs_set/prefs-jq/envtool legs verbatim.
- New `lucidPinShellDark` writeShellApplication + session-scoped oneshot `lucid-shell-dark.service` (After/PartOf/WantedBy graphical-session.target, PATH=lucidPath): writes `current_mode=dark`, re-cps dark face via `--shell-only` when `cmp` differs. Session-scoped oneshot NOT ExecStartPre — lucid's `Restart=always` must not re-darken a manual light flip after crash-restart. Self-heals races: Prefs.qml watches `current_mode`, Theme.qml watches `matugen.json` (both `watchChanges: true`; Theme.isLight derives from palette, not pref).
- Patch layer has ZERO overlap with mode machinery (verified: no patch touches Prefs/Env/Theme.qml/set-mode/apply-theme) — clean ground if ever needed.
- Manual dashboard flip keeps working untouched (upstream setColorMode → set-mode.sh + envtool), flips shell+apps; pin returns dark at next login.
- GTK4: Coloid ships gtk-4.0 CSS and ini chain green; complaint = libadwaita apps ignoring gtk-theme-name by design. They get grayscale tones via user `gtk.css` @import colors.css (loaded by libadwaita apps) + color-scheme auto-flip. Parked alternative: session-wide GTK_THEME force + gsettings monitor (unsupported hack, declined for now).
- QC: fmt explicit files → git add (index eval) → build home.activationPackage -L (shellchecks scripts) → grep built units for lucid-shell-dark / "apply-theme.sh --apps-only" → flake check → dry-build yoga. Plus theme.nix comment + REPO_OVERVIEW.md sync.

Related: [[lucid-grayscale-pair-gtk-diagnosis-2026-10-13]], [[lucid-mode-follow-wallpaper-dock-2026-09-30]], [[plans-for-weaker-executor]].
