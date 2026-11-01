---
name: lucid-mode-follow-wallpaper-dock-2026-09-30
description: Why apps stayed dark + wallpaper vanished after reboot + dock went
  notch — root causes, fixes in lucidAutoMode, live repairs done, pill =
  dockStyle island
metadata:
  node_type: memory
  type: project
  originSessionId: sess_daa269dd-e41c-4b91-9b26-8baaeea1185d
---

2026-09-30 session (branch lucid-testing, on top of the staged [[lucid-hardening-quickshell-flake-2026-09-30]] work, same uncommitted index):

**Apps stayed dark (Firefox + GTK/libadwaita)** — Firefox was already on the AUTO theme (`extensions.activeThemeID = default-theme@mozilla.org` in ~/.config/mozilla/firefox/default/prefs.js), it follows `org.gnome.desktop.interface color-scheme` via xdg-desktop-portal-gtk. Two stacked root causes:
1. `gs_set` in lucidAutoMode lost the uwsm schema-import race at EVERY login (journal 10:52 + 15:32: all three keys "skipped") → dconf stuck `prefer-dark` while envtool's ini files went light = split state. Fix: gs_set now falls back to schema-less `dconf write "/org/gnome/desktop/interface/$key" "'$value'"`.
2. Lucid's persisted prefs (`envColorScheme/envGtkTheme/envIconTheme` in ~/.config/quickshell/lucidprefs/prefs.json) are re-applied by Env.qml at every shell start (`envAdopted` → envtool.apply writes color-scheme + theme names to gsettings, envtool.py:588-589); a manual Theme-page flip persists them (Prefs.setColorMode) but the timer never synced them → every lucid restart re-darkened gsettings in daytime. Fix: lucidAutoMode jq-syncs the three keys to the flipped mode (same payload as a manual flip). The old comment claiming "envColorScheme deliberately stays auto" was wrong.

**Wallpaper "gone again"** — theme switched matugen→static `nord` 10:52, first reboot with nord at 15:32: set-mode.sh only re-applies the image for matugen/pywal; impermanence wiped unpersisted `~/.cache/awww` → awww-daemon "failed to read cache file" → color 000000, and Dock.qml only falls back when current_wallpaper is EMPTY (it was intact). Fix: lucidAutoMode repairs the image for static themes when `awww query` shows no image + `.cache/awww` added to persistence (hosts/yoga/home.nix).
⚠️ **awww query token is `image:` / `color:`** — `grep -q img` does NOT match "image:" (no such substring). Caught by live verification.

**Dock pill** — runtime setting in lucidprefs/prefs.json, repo never manages it: `"dockStyle": "notch"` = attached; `"island"` = pill (radius=height/2, floats `dockBottomMargin`=20px above bottom edge, centered). Prefs.qml FileView watches the file → live pickup, NO lucid restart (KillMode=process issue: restart kills dock-launched apps). Fallback UI: Lucid Settings → General → Dock-Stil → „Inseln" (German patch). Flipped live 2026-09-30; autohide stayed true (user's pref; exclusiveZone 0 + 3px reveal strip).

**Live state repaired same day (pre-switch):** wallpaper re-applied from persisted state; dconf = prefer-light/Colloid-Light-Nord/Fluent (verified readback); prefs env* synced to light; dock island. Kitty stayed dark-pinned ([[kitty-vs-ghostty-evaluation]] choice; user asked about Firefox/system apps, not terminal; questions unanswered → conservative defaults).

Repo edits staged: home/lucid.nix (wrapper + comment), hosts/yoga/home.nix (.cache/awww), REPO_OVERVIEW.md lucid.nix cell updated. QC: flake check + dry-build green; generated wrapper verified from store (nix indented-string trap: bash `${prefs}` needs `''${prefs}`). GAP until switch: the 19:00 boundary still runs the OLD wrapper (no prefs sync) — if user switches after 19:00, prefs stay "light" until next login/boundary.
