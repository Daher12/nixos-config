---
name: update-sweep-2026-10-16
description: Full update sweep EXECUTED+QC green STAGED —
  nixpkgs/HM/sops-nix/nixos-hardware, opencode v2.0.27 (v2.0.28+ flake-broken
  upstream!), mikromcp 1.14.0, dank-greeter a8b10633, lucid v1.20.1 @ 8bc32666
  with 3 repaired hunks; user still must switch + smoke-test
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e8363ef5-bfaa-4cd2-90ad-ff42521163c8
---

Update sweep 2026-10-16, all STAGED (11 files, never committed). QC: flake check + dry-builds yoga/latitude/nix-media all exit 0.

- **Infra**: nixpkgs 26.05 7c8764b→26f4107, home-manager→32904df, sops-nix→4493170, nixos-hardware→60a6244 via update-safe. Hyprland STAYS 0.55.4 on the 26.05 branch (runbook floor scoped to Lua binds, accepted). Transitive crane/rust-overlay/git-hooks/flake-utils deliberately not updated (only move with lanzaboote/preload-ng).
- **opencode v2.0.26→v2.0.27 — NOT v2.0.31**: upstream flake UNBUILDABLE since v2.0.28 (verified unfixed on main 2026-10-16): `packages/cli/script/build.ts` imports `../../../script/native-arch` but `nix/node_modules.nix`'s `lib.fileset` union omits `../script` → whole dir missing from build source. Diagnostic trail: nix-store source tree missing script/ vs GitHub archive complete → upstream flake filter. Retry newer tags only after upstream adds `../script`. Reason documented in flake.nix comment block.
- **mikromcp 1.13.1→1.14.0**: deps byte-identical but npmDepsHash STILL changed (jq round-trip of package-lock rewrote it) → real hash `sha256-0UGVcE7hngboVUl3NeEw3edaagFZGbF8E0rxItFv54M=`. Lesson: never assume hash stability; the "got:" line in the failed build is the fix.
- **zcode stays 3.14.5** (CDN probe 3.14.6–3.15.0 all 404).
- **dank-greeter 334b2c9→a8b10633** (+dank-qml-common 2416d14): session-list/XDG fixes, Go 1.27. Verified only on next boot.
- **lucid e662954(v1.20)→8bc32666 (v1.20.1 + 4 commits)**: 3 hunks re-expressed on upstream's new C/F unit system (`Units.deg`/`Units.wind`): 115 ClockToday chip row, 113 LockWeather (H/T/gefühlt), 114 BluetoothPanel ("Umbenennen" + NEW translation "Dateien senden" — added beyond old mapping, FLAGGED for user veto). stateFiles remedy: `luciddesktop/icons.json` entry with `file = ""` + seed loop skips empty-file entries (upstream ships no default; carries over from backup only). P2 clean (offsets only), P5 markers all pass (5 unmarked lucidlock files = pre-existing baseline, 113 never touched them), attribution diff 42 files all mapped to inventory. Runbook Appendix B + header updated.
- **Upstream features to watch post-switch**: lucid's new "Theme: follow the wallpaper into light or dark" may interact with [[lucid-shell-dark-apps-auto-2026-10-13]] apps-auto/shell-dark split — check for double theme-switching; fingerprint unlock + desktop icons + startup page are new untranslated English surfaces.

**Why:** pins that look "same deps" can still change hashes; upstream flakes rot silently — tag bumps need a real build gate every time.

**How to apply:** next sweep — retry opencode >v2.0.27; re-check `nix/node_modules.nix` fileset for `../script`. For lucid triage: sparse-checkout worktree (`!/wallpapers/ !/assets/sounds/`, 11MB vs 1.5GB) + per-patch git-commit snapshots (`git diff <commit>^ <commit> -- ':(exclude)*.orig'`) — NEVER `cp -r` snapshots on the 2GB /tmp tmpfs (filled it; [[lucid-v120-polish-plan-2026-10-10]] gotcha reconfirmed). `$?` after `nix build | tee | grep | head` masks nix's exit — burned twice now; always `set -o pipefail` (the "green" toplevel build that was actually red).
