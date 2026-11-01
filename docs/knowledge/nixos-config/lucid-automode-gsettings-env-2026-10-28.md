---
name: lucid-automode-gsettings-env-2026-10-28
description: lucid-auto-mode 34s fix EXECUTED — LIVE+VERIFIED by 2026-10-28
  08:22 switch (sub-second runs, zero warnings; 19:00 timer run = final
  at-scale proof)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_949d046e-a2d6-4282-a52d-dc5a9d0e9971
---

lucid-auto-mode 34.5s runs ROOT-CAUSED+FIXED 2026-10-28. EXECUTED+QC green, STAGED on top of the user's parallel lucid bump (pin 8bc32666→4b8fc9a4, only change in home/lucid.nix was a lucidPatched postPatch *.orig cleanup — no interaction).

Root cause (structural, NOT the script's "uwsm login race" theory — disproven by 30/30 failed runs since 2026-10-12 incl. mid-session 8/19 timer fires): lucid-auto-mode.service and lucid-shell-dark.service carried only PATH; gsettings failed instantly "No schemas installed" → gs_set burned 5×sleep 2 ×3 keys ≈30s → dconf fallback. lucid.service had the fix since 2026-10-12, a day BEFORE auto-mode was created — never inherited.

Fix (all in home/lucid.nix): `lucidGsettingsEnv` let-binding (GSETTINGS_SCHEMA_DIR + GIO_EXTRA_MODULES, same strings as lucid.service) `++`-appended into all three unit Environments; gs_set comment rewritten to the real cause (retry+dconf fallback kept as genuine-race belt-and-braces); lucidSync activation gains `find "$LUCID_DIR" -maxdepth 1 -name '*.sh' -exec chmod +x` after the support/lucid rsync. Exec-bit mechanism (empirically verified): rsync -rt PRESERVES source modes for new files — upstream ships sync-starship.sh 444 (matugen-options.sh too, but that one is only ever sourced), the existing `chmod -R u+rwX` turns 444→644, still non-exec → apply-theme.sh:334 EACCES "could not repaint starship" every run since 2026-10-12. Nothing waits on the unit (graphical-session.target only Wants it) — it delayed only itself, but it also silently no-op'd apply-theme.sh's GTK color-scheme reload nudge.

QC (two rounds; round 2 caught a wrong comment, fixed+re-gated): flake check exit 0 (all hosts + statix/nixfmt/deadnix); fmt idempotent; generated auto-mode+shell-dark units carry both vars (same store paths as lucid.service); lucid.service diff vs deployed = BYTE-IDENTICAL (dedup behavior-preserving); generated lucid-auto-mode script vs deployed differs ONLY in the comment block; lucidSync .data verified post-correction; apply-theme.sh byte-identical old→new source, sync-starship call + gsettings nudge (326-330) intact in bump; dry-build yoga exit 0 (re-run after comment fix). KEY env proof: exact unit env + both vars → gsettings get returns live 'prefer-dark'; WITHOUT vars but XDG_DATA_DIRS unset → rc=0 yet returns 'default' (schema default, no dconf backend) — schemas alone would make gs_set "succeed" against defaults, the original Firefox-stays-dark trap; BOTH vars are load-bearing. QS_DIR .sh survey: all upstream 555, no latent same-class bug there. NOT committed. Pending: user switch + verify `journalctl --user -u lucid-auto-mode -b` clean, run ~5s; no lucid restart needed (env unchanged there); starship palette + GTK nudge become visibly active (intended).

Eval gotcha: this HM version exposes `home.activation.<name>` attrs as {after,before,data} — `.text` does NOT exist; use `nix eval --raw …home.activation.lucidSync.data`. Related: [[lucid-wifi-129-2026-10-24]], [[lucid-shell-dark-apps-auto-2026-10-13]], [[parallel-index-work]].
