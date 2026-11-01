---
name: lucid-glass-frost-plan-2026-10-11
description: Lucid Glass frost — kitty include fix + GTK enable EXECUTED+QC green
  STAGED 2026-10-11; frost already compositor-side; perf LOW; switch+kitty
  restart+GTK test pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c5e592d7-1648-4ebd-aa8c-abf67c7543ee
---

Status 2026-10-11 evening: EXECUTED by the planning session itself (user: "execute plan"). ALL QC GREEN, STAGED uncommitted: flake check exit 0 first try, dry-build yoga exit 0, byte-gate diffs exactly the intended deltas (kitty.conf: −`background_opacity 0.93`, +`include /home/dk/.config/kitty/lucid-glass.conf` as LAST lines = last-wins proven; hyprland.lua: +6 comment lines + realigned blur block adding noise 0.04 + ignore_opacity true). Switch + user steps PENDING.

**Deviations from approved plan text (both improvements):** (1) the 0.93 opacity is NOT dropped unconditionally — kept via `lib.optionalAttrs (!config.desktop.lucid.enable)` for the GNOME generations (latitude, yoga-gnome) where lucid-glass.conf never exists (unconditional include would kitty-error there); include + settings-change both gated on desktop.lucid. (2) blur block realigned to `ignore_opacity` width (cosmetic churn beyond the promised 2 lines).

**Plan history:** approved via second ExitPlanMode (first rejected with test feedback "kitty and gtk apps don't blur" at Balanced → diagnosis round 2).

**Architecture finding (v1.20, pinned e662954):** lucid Glass IS compositor-side frost — surfaces attach `BackgroundEffect.blurRegion` (ext-background-effect-v1; Hyprland 0.55.4 implements it, PR #13211), Hyprland renders via the existing `decoration.blur` block in home/hyprland.nix (enabled/size 10/passes 2/vibrancy 0.2). NO shell-side QML blur on bar/dock/settings. The Settings warning = Hyprland frost quirks: bar tint samples the window beneath (drifts), kernel reach ≈ size×passes px past edges. 0.55.4 is known-good for protocol blur (0.56 regressed, #15529).

**Glass state:** one slider (Settings → General → Glass, Off/Light/Balanced/Heavy/Full = 0/.2/.5/.8/1) writing `~/.config/quickshell/lucidbar/blur.json` (stateFile → survives rsync --delete + reboots; `watchChanges` hot-applies). User set Balanced 0.5 for testing 2026-10-11. Deliberately NOT pinned in Nix (Light 0.2 is also the seed default; a guarded flip would fight the slider). Weights: shell α = 1−0.85×, kitty = 1−1× (selfManaged via own config), listed apps = 1−0.25× → at Balanced 57.5%/50%/87.5%. Live glassValues: kitty=0.5 (set apart), vscodium=0.9 (set apart), zcode follows 0.88.

**Root causes of user's test failure:**
1. kitty: HM owns kitty.conf as read-only store symlink → lucid `linkProc`'s `>> include ./lucid-glass.conf` failed EACCES silently at 2026-10-11 20:56, and the leftover `kitty.conf.pre-lucid-glass` (444) is lucid's permanent "already done, never retry" marker. lucid-glass.conf itself (dynamic_background_opacity yes + background_opacity 0.50) is written correctly — nothing includes it.
2. GTK apps (Files=org.gnome.nautilus, Text Editor=org.gnome.texteditor): in Glass catalog but never checked in glassApps → no opacity rule → opaque. Caveat: Hyprland 0.55.4 `ElementRenderer.cpp` cancels blur when client-declared opaque region covers surface; GTK 4.24 declares opaque → may render dim-without-frost even with rule (#16508, closed not-planned). Decision rule: frosted→keep, dim→uncheck (leave GTK opaque). Electron (vscodium/zcode) frosts fine.

**Executed edits (2 files, STAGED):**
- home/terminal.nix: kitty settings no longer carry `background_opacity` unconditionally — kept via `// (lib.optionalAttrs (!config.desktop.lucid.enable) { background_opacity = "0.93"; })` for GNOME gens; `extraConfig = lib.mkIf config.desktop.lucid.enable "include ${config.home.homeDirectory}/.config/kitty/lucid-glass.conf"` (absolute path; header already had `config`).
- home/hyprland.nix blur block: pinned `noise = 0.04, ignore_opacity = true` + 6-line comment (slider state in blur.json; lucid only sets translucency+blur regions; Hyprland renders frost from this block).

**Post-switch user steps (PENDING):** nus → `pkill -x kitty` + reopen once (dynamic_background_opacity only takes for windows started after it loads; then USR1 live-reloads) → kitty row 0.5→0.85 taste; zcode set-apart 1.0 if unwanted → GTK check+test per decision rule → optional `rm ~/.config/kitty/kitty.conf.pre-lucid-glass`.

**QC:** `nix fmt <files explicit>`; `git add` both (flake reads index; re-add after edits); `nix flake check` (retry once on transient lock-race); `nixos-rebuild dry-build --flake .#yoga`; byte-gate home-files diff: kitty.conf = −0.93/+include (proves last-wins ordering), hyprland.lua = +comment+2 lines.

**Perf verdict:** LOW — shell strips cached/damage-driven; 2-pass kawase; static wallpaper; 680M @3072x1920@120 scale 2 with 60Hz-on-battery via battery-refresh → keep apps frosted; shell-only escape = uncheck apps + kitty 100%.

**Fallbacks:** literal `include /home/dk/.config/kitty/lucid-glass.conf` if interpolation bites; `hl.layer_rule({ match = { namespace = "quickshell" }, xray = true })` via desktop.hyprland.extraConfig for wallpaper-frost (stable tint, panels over windows show wallpaper — upstream rejected deliberately); slider Off = kill switch.

**Switched 2026-10-17 (glass-conf persistence entry went live):** yoga/home.nix now persists `.config/kitty/lucid-glass.conf` as an impermanence FILES entry (slider state was resetting each boot). First switch failed exactly like the current_* files before it: `persist-...lucid-glass.conf.service` → "A file already exists at /home/dk/.config/kitty/lucid-glass.conf!" because the live copy wasn't under /persist yet. Fix applied + verified: `mv` the $HOME copy to `/persist/home/dk/.config/kitty/` (preserves slider state, opacity 0.65), then `systemctl start 'persist-persist-home-dk-.config-kitty-lucid\x2dglass.conf.service'` — worked WITHOUT sudo via polkit (contrary to the system-bus assumption); bind mount onto btrfs `@persist` confirmed via findmnt. Unit name literal contains `\x2d` — single-quote it in shell. No rebuild needed; config is correct, this is the documented first-switch migration (comment at hosts/yoga/home.nix:174). Kitty slider state now survives reboots.

Outcome unknown until executor runs + user switches. See [[plans-for-weaker-executor]] for the handoff pattern; lucid pin/update mechanics in [[lucid-v120-minimal-bump-2026-10-09]] and LUCID_RUNBOOK.md.
