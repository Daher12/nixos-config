---
name: noctalia-gtk-templates-plan-2026-11-18
description: EXECUTED 2026-11-18 +fast green, STAGED (switch pending) — GTK4 apps
  stuck dark root cause = orphaned 436KB Colloid-Dark gtk.css at user priority;
  fix = Noctalia builtin gtk3/gtk4 templates ON + live strip DONE
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b1d9adea-eb0d-4398-b1d8-353ad693928b
---

# GTK4 auto light/dark via Noctalia templates — EXECUTED 2026-11-18

User decision (AskUserQuestion): **Noctalia builtin templates** over Colloid dual-variant / darkman retrigger. Plan approved ("execute plan") after an earlier ExitPlanMode denial; EXECUTED same day. Follows [[noctalia-auto-mode-restore-2026-11-17]].

## Root cause (live-verified)

GTK4 apps stay dark in light mode because of an **orphaned 436,926-byte real file `~/.config/gtk-4.0/gtk.css`** — byte-copy of `Colloid-Dark-Nord/gtk-4.0/gtk.css` (window_bg_color #242932, mtime Nov 9, +1 trailing newline). GTK loads it at USER priority → overrides Adwaita/libadwaita/color-scheme. Nothing manages it: HM disowns (theme.nix:151 mkForce false), noctalia templates off (`applied_builtin_ids = ""`), darkman mkIf'd off, `.config/gtk-4.0` persistence keeps it alive. Noctalia's light `colors.css` was orphaned too — the stale gtk.css has no @import of it.

## Plan (approved content)

1. **home/noctalia.nix** theme block: `enable_builtin_templates = false → true`; `builtin_ids = ["gtk3" "gtk4"]` — **drop "btop"** (owned by home/terminal.nix); niri/kitty ids stay OUT (would rewrite Nix-owned files). Rewrite comments ~219-245.
2. **home/theme.nix**: noctalia branch `gtk.theme.name` "adw-gtk3-dark" → "adw-gtk3" (ini = dconf-less fallback only; live gtk-theme key owned by apply.sh's adw-gtk3↔adw-gtk3-dark swap). Rewrite stale comments 94-100 (colors.css lore wrong) + 203-209 (darkman comment claims "fixed dark", dead since 11-17).
3. **hosts/yoga/home.nix** ~138-140 comment touch; **REPO_OVERVIEW.md** :165/:167 entries.
4. **One-time live strip BEFORE rebuild**: rm `~/.config/gtk-4.0/{gtk.css,gtk-dark.css,assets,colors.css,dank-colors.css,settings.ini.backup}`, `~/.config/gtk-3.0/{colors.css,dank-colors.css}`; KEEP `gtk-3.0/gtk.css` (2-byte empty carrier — apply.sh appends import), settings.ini, bookmarks.
5. QC: git add + `nix fmt <files>` + `scripts/test-suite fast`; VM battery expected skip (config values only). User runs rebuild.

## Mechanism lore (v5.5.0 source-verified)

- Noctalia template: regenerates `noctalia.css` (named-colors only, NO prefers-color-scheme media queries — regeneration per flip IS the switch) + runs `assets/templates/gtk/apply.sh dark|light`: injects `@import url("noctalia.css")` into `~/.config/gtk-{3,4}.0/gtk.css` (converts read-only NixOS symlinks to writable files) + gsettings gtk-theme → adw-gtk3/adw-gtk3-dark. Re-applies on EVERY mode change.
- User-priority noctalia.css recolors libadwaita apps too (user css beats libadwaita stylesheet) — covers GTK3+GTK4+libadwaita.
- GTK4 live-reloads on flip; GTK3 needs restart (upstream caveat). Icons stay Fluent-dark (noctalia doesn't swap icons).
- Testing: invoke apply.sh dark/light directly; **do NOT GUI theme-mode-toggle** (state-layer trap, writes theme.mode override — [[noctalia-auto-mode-restore-2026-11-17]]).
- Store facts: `Colloid-Nord` dual variant exists (gtk.css light #ffffff + gtk-dark.css → Dark-Nord #242932, both gtk-3.0/4.0) — viable zero-script alternative if templates disappoint. adw-gtk3's GTK4 payload is a FAKE dual (identical stubs importing libadwaita.css) — light/dark distinction only in gtk-3.0.
- Old darkman `switch-theme` (theme.nix:26) = gsettings swap + symlink farm into ~/.config/gtk-4.0 — origin of the stale artifacts; kept for GNOME hosts.
