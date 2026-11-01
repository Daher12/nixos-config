---
name: lucid-shell-dark-apps-auto-2026-10-13
description: EXECUTED+QC green STAGED — shell pinned dark (lucid-shell-dark.service login pin), timer drives apps only via apply-theme.sh --apps-only; libadwaita GTK4 accepted limitation; user switch steps pending
metadata:
  type: project
---

EXECUTED 2026-10-13, QC green, STAGED (on top of the grayscale pair work, same index). User decision: **lucid shell rests dark permanently; only apps follow the 08:00/19:00 clock; manual dashboard flips move shell+apps and last until next login.**

**Why:** user wants a dark shell at all times (exceptions only via manual dashboard switch), while apps keep auto light/dark; GTK4 "not applying" = libadwaita ignoring gtk-theme-name BY DESIGN (diagnosis in [[lucid-grayscale-pair-gtk-diagnosis-2026-10-13]]).

**How to apply / what changed (all repo-side, ZERO new patches — patch layer has 0 overlap with mode machinery):**
- `home/lucid.nix` `lucidAutoMode`: static themes → `apply-theme.sh --apps-only <theme> <mode>` (kitty/colors.css/starship/matugen templates, shell palette `~/.cache/quickshell/matugen.json` untouched); derived (matugen/pywal/colour) keep legacy coupled `set-mode.sh`. Wallpaper repair now uses `$shell_mode` (from `~/.cache/current_mode`), not the clock's mode. gsettings/prefs-lockstep/envtool-ini legs unchanged.
- New `lucidPinShellDark` writeShellApplication + `lucid-shell-dark.service` (login oneshot, WantedBy/After graphical-session): writes `current_mode=dark` (Prefs.qml FileView watches it live; anything ≠"light" reads dark), re-applies dark palette `--shell-only` only when `cmp` shows drift. Deliberately NOT ExecStartPre on lucid.service (Restart=always would re-darken after crash-restarts).
- `home/theme.nix`: libadwaita comment only (accepted stock-Adwaita+colors.css-tones look; GTK_THEME force-hack parked, listed in plan).
- `REPO_OVERVIEW.md` lucid.nix row synced.

**Key upstream facts (pin e662954):** `apply-theme.sh [--shell-only|--apps-only]` already existed; `set-mode.sh`/`apply-theme.sh` never write current_mode; shell lightness derives from palette-file tones (Theme.qml isLight), not Prefs.colorMode. Derived-theme pin path = set-mode.sh dark (re-fades wallpaper at login — pre-existing behavior).

**QC done:** fmt, git add (index), `nix build …home.activationPackage -L` green (shellcheck), built units+scripts inspected verbatim, `nix flake check` green, dry-build green.

**User steps:** switch → `systemctl --user start lucid-shell-dark.service` (or relogin) → test `systemctl --user start lucid-auto-mode.service` midday: apps flip light, shell stays dark. Grayscale = static theme → apps-only path is the live one.
