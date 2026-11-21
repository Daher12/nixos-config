---
name: nas-unavailable-diagnosis-plan-2026-11-19
description: PLAN (ExitPlanMode denied, NOT executed) — "NAS not available in
  Nautilus" = NFS automount chain, not Nautilus; diagnosis-first plan with
  branch fixes
metadata:
  node_type: memory
  type: project
  originSessionId: sess_76d092f2-567f-4fda-a2d3-db7a1ccb4ea5
---

User reported "NAS not available through nautilus" on yoga 2026-11-19, broke within ~2 days. Clarified via AskUserQuestion: the NAS **sidebar bookmark**, **endless spinner**, `ls /mnt/nas` **hangs too**, recent regression.

**Diagnosis (exploration, plan-mode):**
- Nautilus/gvfs EXONERATED: bookmark is just `file:///mnt/nas` (hosts/yoga/home.nix:21-26,278-279); gvfs 1.60.3 enabled with full backends (desktop-niri.nix:123); automount registered.
- The "NAS" = NFSv4.2-over-Tailscale automount: features.nas (modules/features/nas.nix) → nix-media 100.123.189.29:/ , `soft,timeo=600,retrans=2`, gated on tailscale-online.service (45s timeout oneshot). Server: roles/media.nix NFSv4 pseudo-root export /mnt/storage fsid=0; nix-media firewall opens 2049 on tailscale0 only.
- timeo=600 (60s/retry) explains multi-minute hang/spinner on unreachable server.
- NO SMB anywhere in the fleet (avahi/wsdd absent, dead by design); REPO_OVERVIEW.md:98 "NFS/SMB" row is STALE.
- Uncommitted desktop-niri.nix diff (niri-session env fix) = red herring.
- Candidates: Nov 18 nixpkgs sweep (kernel 7.3.4-zen2 + tailscale both ends), Nov 18 nix-media audit rebuild, Tailscale key expiry.

**Plan (delivered via ExitPlanMode, permission denied — nothing executed):** Phase 1 diagnose on yoga (tailscale BackendState + ping, /dev/tcp probe :2049, unit/journal, `timeout 25 ls /mnt/nas`), branch A tailscale re-auth (user-run), B nix-media server side (ssh backgrounded — [[nix-media-tailscale-ssh-access]]), C NFS error specifics. Phase 3 hardening: add `x-systemd.mount-timeout=30s`, timeo 600→150 in nas.nix for fail-fast instead of spinner; fix REPO_OVERVIEW row. QC via [[test-suite-shared-runner-2026-11-01]] fast + suggest gate.

**Why:** symptom attribution matters — Nautilus bookmark issues are usually the mount chain, not GNOME.
**How to apply:** if NAS issue recurs, check tailscale/nix-media reachability first; mount options make failures slow by design.
