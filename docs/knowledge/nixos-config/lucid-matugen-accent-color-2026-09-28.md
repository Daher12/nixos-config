---
name: lucid-matugen-accent-color-2026-09-28
description: Lucid palette control 2026-09-28 — matugen seed lever =
  set-wallpaper.sh --source-color-index (0 = dominant = the blue; 4 candidates
  previewed, 1 = golden); user PIVOTED to static import: Rosé Pine via
  edunfelt/base16-rose-pine-scheme (3 variant YAMLs in one repo, Moon default /
  iris accent); GUI import = Moon always (UI passes no variant), clunky
  auto-label; ⚠️ imported themes wiped by lucidSync --delete on the NEXT
  rebuild after import, 2-line home/lucid.nix fix PROPOSED; NOTHING executed,
  user preparing GUI import themselves, no fix go-ahead yet
metadata:
  node_type: memory
  type: project
  originSessionId: sess_edc95bc4-614e-4fcb-bbd0-9465f970e7ef
---

2026-09-28 session: user asked how to de-blue the wallpaper-matched matugen accent (wifi icon, borders) while KEEPING wallpaper matching. Answer delivered as analysis only — status PROPOSED, awaiting user's index pick (1 suggested).

**Root cause / architecture facts:**
- Lucid seeds matugen at exactly ONE site: `support/wallpaper/set-wallpaper.sh` (~line 124): `matugen image "$WALLPAPER" -m "$MODE" --source-color-index 0` — index 0 = most dominant image color. For golden-mist-valley.jpg that's the blue-grey sky `#5b8395` → primary `#8ad0ef` = the blue everywhere.
- `Theme.accent` = matugen `primary` directly (Theme.qml:92); the Lucid Settings `accentPunch` pref changes LIGHTNESS only, not hue — no user-facing hue preference exists.
- kitty + GTK follow automatically via the same matugen templates (config.toml authored in home/lucid.nix; templates symlinked from lucidPatched store tree).
- matugen 4.0.0 `-t` scheme types (tonal-spot default, neutral, rainbow, …) alter chroma but NOT the primary hue family — NOT the lever for "too much blue".
- set-wallpaper.sh deploys via xdg.configFile symlink chain → lucidPatched store tree; direct ~/.config edits wiped by rsync --delete each activation → fix = new build-time patch `home/lucid-patches/004-matugen-seed.patch` (one line, index 0→N), riding the [[lucid-buildtime-patches-2026-09-28]] infrastructure.
- Theme routing: ~/.cache/{current_theme,current_mode,current_wallpaper}; theme=matugen|pywal|static; static themes in ~/.config/lucid/themes/ (nord, gruvbox, catppuccin-mocha, nightfox, tokyo-night).

**Previewed candidates (dry-run, golden-mist-valley, dark mode) — this image yields exactly 4 (indices 0–3; out-of-range error text "N is not in 0..4" actually means 0..3):**
- index 0 CURRENT: seed #5b8395 slate blue → primary #8ad0ef sky blue
- index 1 RECOMMENDED: seed #c4b69d warm sand → primary #e8c26c golden
- index 2: seed #d8ac86 apricot → primary #feb877 warm orange
- index 3: seed #8c7873 taupe → primary #ffb5a1 soft coral

**Caveat given to user:** index = "Nth most dominant color of whatever wallpaper", not a stable avoid-blue rule — next wallpaper's index 1 may be blue again. Escalations offered: fixed seed `matugen color <hex>` (stable, loses wallpaper match), a script auto-picking the extracted candidate nearest a target hue, or lucid static themes (abandon matching entirely).

**If executed later:** rebuild, then re-trigger palette via `~/.config/lucid/set-mode.sh dark` (or re-pick wallpaper). Live trial without rebuild: `matugen image ~/Bilder/wallpapers/golden-mist-valley.jpg -m dark --source-color-index 2` rewrites the live palette; restore = re-run with 0 or re-pick wallpaper.

**Reusable technique:** safe preview (writes nothing) = `HOME=$(mktemp -d) matugen image <img> -m dark --source-color-index <i> --dry-run -j hex`. JSON shape in matugen 4.0: `{"colors":{"primary":{"default":{"color":"#..."}}}}` — key is `.color`, NOT `.hex` (parse failed until corrected).

**2026-09-28 follow-up — user pivoted to a static theme import.** Stock lucid themes ALL rejected ("not to my liking"); wants a GitHub palette "close to matugen", suggested Rosé Pine. Deliverable = assessment only: NOTHING executed, live palette untouched (current_theme=matugen, mode=dark, wallpaper=golden-mist-valley.jpg, live accent #8ad0ef). Turn ended offering to stage the lucid.nix fix + run the import — awaiting user go-ahead.

- **⚠️ TRAP: imported themes do not survive a rebuild.** Upstream ships `themes/` inside `support/lucid/`, and the support rsync (home/lucid.nix lucidSync, the one with the keybinds.json excludes) runs `--delete` → anything imported into `~/.config/lucid/themes/` is DELETED on the next nixos-rebuild switch / boot activation. Fix (2026-09-30: included verbatim in the approved hardening handoff, see [[lucid-audit-quickshell-flake-2026-09-30]]; not yet applied): add `--exclude 'themes'` to the deleting sync + a second non-deleting `rsync -rt "$LUCID_SRC/support/lucid/themes/" "$LUCID_DIR/themes/"` so builtin themes still update. (Side effect accepted: upstream-removed builtins linger.)
- Import tool: `~/.config/lucid/add-theme.py <git-url> [--variant NAME] [--name LABEL] [--list]` — 3-tier detection: base16 YAML (≥8 baseXX keys), name-keyed JSON (≥8 #hex values), else hex-frequency harvest (roles guessed by chroma rank, red reserved for error). Sorted dark-first, then closest bg tone to 12 → Moon beats Main as default. Also in Settings → Theme URL field (ThemePage.qml:55) but the UI passes no --variant/--name (ugly auto label). Outputs `themes/<id>/{quickshell.json,meta.json}` + wallish images to `~/Pictures/wallpapers/<id>`. Zero-risk full preview proven: `HOME=$(mktemp -d) python3 ~/.config/lucid/add-theme.py <url>`.
- Repo selection facts: `rose-pine/rose-pine` does NOT exist (git's "access rights / repository exists"-style tail is also what a missing repo looks like — probe with a known repo to tell network-block from 404); canonical `rose-pine/palette` DEFEATS the importer (role-list JSON arrays, hexes WITHOUT `#`, and its ready-made files live in `dist/` which is in SKIP_DIRS). WORKING SOURCE: `https://github.com/edunfelt/base16-rose-pine-scheme` — exact role mapping. Default = **Rosé Pine Moon**: accent #c4a7e7 iris violet, secondary #9ccfd8 foam, tertiary #3e8fb0 pine, error #eb6f92 love, surfaces #232136 ladder; variants: Moon / Rosé Pine (Main) / Dawn; 3 wallpapers come along. Recommended CLI: `--variant "Rosé Pine Moon" --name "Rosé Pine"`. Accent taste option: iris is just the base16-port mapping; rose #ebbcba or gold #f6c177 as primary = 2-value edit in the theme's quickshell.json afterward (user themes are plain JSON, fully hand-tweakable once the rsync fix lands).
- Alternatives dry-run: rebelot/kanagawa.nvim imports via base16 but lands BLUE #7e9cd8 (out — exactly what user is escaping); sainnhe/everforest lands warm gold #dbbc7f but via low-confidence `harvest` tier (ranked: below Rosé Pine for predictability).
- Static theme = FULL-desktop swap, not shell-only: apply-theme.sh writes the SAME `~/.cache/quickshell/matugen.json` Theme.qml reads (Theme.qml:347 — both paths converge on one palette file), rewrites kitty matugen-colors.conf (+ `killall -SIGUSR1 kitty`), gtk-3.0/4.0 colors.css, vscodium, vesktop, starship, spicetify, steam. Light variant synthesized into `themes/<id>/quickshell-light.json` on first light apply; 08:00/19:00 auto light/dark timer keeps working. Wallpaper matching ENDS while a static theme is selected — revert = one click to Matugen in Settings; the golden-seed 004-patch option (above) stays open if user wants matching back later.
