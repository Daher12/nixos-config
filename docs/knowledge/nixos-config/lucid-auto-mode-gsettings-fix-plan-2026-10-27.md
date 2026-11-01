---
name: lucid-auto-mode-gsettings-fix-plan-2026-10-27
description: lucid-auto-mode 34.5s runs root-caused (unit env missing
  GSETTINGS_SCHEMA_DIR/GIO_EXTRA_MODULES — NOT the uwsm race its comment claims)
  + sync-starship.sh 644 EACCES; full fix plan ready in home/lucid.nix,
  ExitPlanMode DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_949d046e-a2d6-4282-a52d-dc5a9d0e9971
---

SUPERSEDED: this plan was EXECUTED 2026-10-28 (user commanded "execute plan, beware, we just bumped lucid-shell") — execution record + QC evidence in [[lucid-automode-gsettings-env-2026-10-28]]. Bump-safety verified: apply-theme.sh byte-identical old→new lucid source, sync-starship call + gsettings nudge intact. Only deviation from the plan below: home.activation entries expose `.data` not `.text` in this HM version (nix eval gotcha). Everything below is the historical plan/diagnosis.

Follow-up to [[yoga-slowboot-gc-catchup-2026-10-27]] (user reversed the initial "decline" and asked for analysis). Plan delivered; first ExitPlanMode denied, executed next turn on explicit user command.

## Root cause (proven, reproduced by Explore agents)

- `lucid-auto-mode.service` env (home/lucid.nix ~946-948) sets ONLY `PATH`. Without `GSETTINGS_SCHEMA_DIR`, gsettings fails instantly ("No schemas installed", ~4ms), so the wrapper's `gs_set` loop (~366-379: 5 × fail+sleep 2 per key × 3 keys ≈ 30s) burns against a PERMANENT failure, then dconf-fallbacks. 34.5s runs.
- Fix precedent in same file: `lucid.service` got `GSETTINGS_SCHEMA_DIR` + `GIO_EXTRA_MODULES` 2026-10-12 (~896-902); auto-mode unit created Oct 13 and never inherited them — its own comment even notes the symptom.
- The in-code "uwsm environment import race at login" theory (~358-365) is DISPROVEN: 30/30 runs failed since Oct 12, incl. mid-session timer runs (Oct 17 13:35, Oct 24 12:04). Live repro: unit env replica → instant failure; +schema dir → instant success. GIO_EXTRA_MODULES is inherited from the user-manager env; schema dir never is.
- Impact honesty: NOTHING waits on the unit (graphical-session.target only Wants it) — it never delayed login/desktop, only itself + journal spam (90 warnings; 2 timer runs/day + every login).
- Same env also silently starves apply-theme.sh's gsettings GTK-reload nudge (its `gsettings get` no-ops) inside auto-mode/shell-dark runs.
- Bonus defect: `sync-starship.sh` deployed mode 644 (rsync -rt at lucid.nix ~585-588 carries no exec bits for NEW files; landed with v1.20) → apply-theme.sh exec EACCES → "could not repaint starship" every run; starship palette has NEVER synced.

## Fix plan (ready, not executed)

All in home/lucid.nix, no new files/patch-layer/pin moves:
1. `let lucidGsettingsEnv = [ GSETTINGS_SCHEMA_DIR=...gsettings-desktop-schemas... ; GIO_EXTRA_MODULES=...dconf.lib... ];` after lucidPath — BOTH vars required (schema dir alone reads defaults "Adwaita" instead of live dconf db).
2. lucid.service: dedup to `] ++ lucidGsettingsEnv` — must stay byte-identical (QC diff).
3. lucid-auto-mode + lucid-shell-dark: `Environment = [ "PATH=${lucidPath}" ] ++ lucidGsettingsEnv;`
4. Rewrite gs_set comment (drop uwsm-race theory; keep loop + dconf fallback as belt-and-braces).
5. After lucidSync rsync: `find "$LUCID_DIR" -maxdepth 1 -type f -name '*.sh' -exec chmod +x -- {} +` (findutils).
6. QC: nix fmt (explicit path) → home-files build, grep both env vars in generated auto-mode/shell-dark units, byte-diff lucid.service → `nix eval` home.activation lucidSync text → dry-build .#yoga. No commit.
Expected: 34.5s → ~5s runs, warnings gone, starship sync + GTK nudge start working (intended behavior deltas to watch post-switch).
