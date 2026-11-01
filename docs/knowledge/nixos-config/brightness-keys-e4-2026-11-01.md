---
name: brightness-keys-e4-2026-11-01
description: Lucid brightness keys stepped quartic (-e4) vs linear display →
  uneven steps; FIXED live 2026-11-01 by rewriting keybinds.json cmds to
  brightnessctl -n2 set 10%± (user chose 10%); no repo patch, self-maintaining
metadata:
  node_type: memory
  type: project
  originSessionId: session_9004ed79a4629029ff8087062b845152
---

Uneven brightness stepping in lucid (granular at low, 20–30% jumps near max) diagnosed + FIXED 2026-11-01, LIVE (no rebuild needed, no patch, NOTHING to maintain).

**Root cause (evidence-backed):** brightness keys are lucid's, not Hyprland's — `~/.config/lucid/keybinds.json` `xf86-bright-up/down` exec `brightnessctl -e4 -n2 set 5%±` (seeded from upstream `support/hypr/keybinds.json`). `-e4` = quartic curve: +5 curved points = `(raw/max)^0.25`, so one press = +18.5 linear points near max (saturates >81% curved straight to 100) and ~2 points at the bottom. Bar/OSD/sliders/idle-dim are all LINEAR percent (`System.qml`/`Osd.qml` `Math.round(raw/max*100)`, write plain `set N%`), so display and key-step spaces disagree. No repo lucid patch touches brightness; hardware is fine (one device amdgpu_bl1, max 65535, `scale: non-linear`, amdgpu applies its own map: actual_brightness 6477 vs brightness 4096).

**Fix (executed):** jq-walk rewrote all 4 brightness cmds (2 enabled XF86 + 2 disabled F5/F6) to `brightnessctl -n2 set 10%±` — user explicitly chose 10% steps, not 5. Backup at `~/.config/lucid/keybinds.json.bak-2026-11-01`. Applied live with `hyprctl reload` (status file `$XDG_RUNTIME_DIR/lucid-keybinds-status.json`: 55/55 applied, 0 failed). `-n2` floor kept (never fully off).

**Durability (verified against every writer of the file):** lucidSync rsync `--exclude`s keybinds.json (home/lucid.nix ~609); repo+upstream seeds only fire when the file is absent/empty (`! -s`); all migrations (ghostty→kitty, F-row disable, lumen revert, exit rewrite + upstream's two) guard on the exact old value and none touch brightness cmds — a user-modified cmd never matches a guard. Same edit is self-service in Lucid Settings → Keybinds (applies live via hyprctl reload on save).

**Onset finding (user said "started 1–2 weeks ago" — NOT lucid):** `-e4` byte-identical since lucid first deployed here 2026-09-23 (commit d958241 Sep 1 upstream; the pre-lucid era was DMS `dms ipc call brightness increment 5`); linear display since v0.91 beta (04aac70 Aug 23). Suspects for the perceived onset: kernel/nixpkgs bump in the Oct 24–31 window changing amdgpu's non-linear backlight mapping, or simply operating in the upper range where the quartic is worst. If stepping feel changes after a future kernel bump → amdgpu layer, not the shell.

**Lore:**
- binds.lua (`support/hypr/modules/binds.lua`) reads keybinds.json once per Hyprland config load — a file edit is one `hyprctl reload` away; `systemctl --user restart lucid` does NOT re-apply binds (only the UI list).
- brightnessctl `-eN` curve flags: `-e4` on this 65535-max panel makes `set 50%` = raw 4096; plain `set 50%` = 32768. `--pretend` is the read-only probe.
- chmod `--reference=~...` does NOT tilde-expand after `=` in bash — use `--reference="$HOME/..."`.
