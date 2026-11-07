---
name: branch-split-vps-dms-niri-2026-11-06
description: Mixed 32-file staged bundle split into vps/dux-shell/niri-testing
  branches, QC green, stash backup kept
metadata:
  node_type: memory
  type: project
  originSessionId: session_136694fc253dd290e00cad77845d4064
---

EXECUTED 2026-11-06 + QC green (`test-suite fast` per tip). The VPS+DMS+niri work that sat as ONE 32-file staged bundle on main was split into three stream-pure branches (user decision: VPS gets own branch; keep names dux-shell + niri-testing):

- `vps` = `d34fbe2` (off main): hosts/vps/**, scripts/vps-*, secrets/hosts/{vps,nix-media-gatus}.yaml, ntfy.nix gatus heartbeat, vpn.nix advertiseExitNode, vps/vps-install flake attrs, test-suite vps entries.
- `dux-shell` = `9bf6fe1` (off main): home/dms.nix + dms-themes, dux-shell flake input + flake.lock nodes, desktop-hyprland dms wiring (shellIpc, dmsLockAtBoot, dms option), home/theme.nix, profiles/desktop-hyprland dms defaults, update-safe --pin, yoga dms persistence.
- `niri-testing` = `2ff4f37` (ff-merged ONTO dux-shell — niri consumes dux-shell modules, must stack): home/niri.nix, desktop-niri feature/profile, yoga-niri attr, REPO_OVERVIEW niri rows, desktop-gnome niri assertions, yoga niri persistence.

**Why:** user thought VPS commits got mixed into wrong branches; reality = nothing was ever committed (no dms/niri branches existed, only empty pointers at main's tip). Mixing happened in the git index. main untouched (== origin/main, 3388242).

**How to apply:** lossless-union proven via `git diff <branch> stash@{0}`. `stash@{0}` = "backup: mixed vps+dms+niri staged bundle pre-split 2026-11-06" — KEPT as recovery, drop only after user confirms branches good. Nothing pushed (user's call). Open follow-ups: (1) `.sops.yaml` has NO creation rule for secrets/hosts/vps.yaml + nix-media-gatus.yaml (no host_vps key in `keys:`) — verify `sops -d` works before any vps/nix-media switch that reads them; (2) REPO_OVERVIEW.md lacks VPS host rows, and dux-shell branch lacks rows for home/dms.nix. **QC round 2026-11-06 (same day, second session): ALL PASS** — commit file sets exact (16/11/11), ancestry verified, attr sets per branch proven via `nix eval` (vps=6 hosts no yoga-niri, dux=4, niri=4+yoga-niri), flake.lock↔flake.nix consistent per branch, all test-suite variants bash -n OK + exec bit kept, VM battery legitimately skipped (host-units-smoke boots latitude/GNOME where dms/niri are disabled). Memory-index maintenance done in the same round: MEMORY.md 27.6KB→22.9KB (was over the 24.4KB load limit; 132/132 entries preserved, wording-only trim; 3 stale STAGED→COMMITTED status lines fixed). Pre-existing: **15 topic files have NO index pointer** (orphans incl. config-audit-2026-10-03.md, noctalia-integration-plan.md, quickshell-icon-provider-crash-2026-10-10.md) — curation pass pending, adding all 15 ≈ +2KB nears the limit again.

Related: [[niri-testing-trial-2026-11-05]], [[vps-watchdog-exitnode-plan-2026-11-01]], [[git-file-ref-branch-testing]].
