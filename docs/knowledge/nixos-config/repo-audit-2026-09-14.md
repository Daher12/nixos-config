---
name: repo-audit-2026-09-14
description: full-repo audit 2026-09-14 — all fixes staged on main (mnamer move,
  dead config, README rewrite, latitude nftables, fuse+lix-cache removal);
  pending only sops re-encryption
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ee6557ac-8790-4a21-931f-a4446cae1478
---

Full repo audit + README refactor, 2026-09-14. Work started on `testing`, user merged to `main` mid-task and chose to keep the work there ("ride or die"). **Committed as `8468fe2` on main, NOT yet pushed** (user authorized commit only).

**Applied (QC-proven, flake check + dry-build all 3 hosts green):**
- `hosts/nix-media/mnamer.nix` → `modules/features/mnamer.nix`; yoga imports it now too — measured eval delta within noise (~0.8s either way, 19 option names added, config behind `mkIf false`).
- nix-media: redundant `cleanOnBoot` + mnamer default-restatements dropped; mnamer config.json store hash byte-identical (`7ma0nc2g…`).
- latitude: yoga's nftables SSH LAN-restriction mirrored (22 only from 192.168.88.0/24 + tailscale0 trusted; `openFirewall = false`). Eval-verified `allowedTCPPorts=[]`. **Activates only at latitude's next rebuild** — Tailscale SSH unaffected.
- yoga: `programs.fuse.userAllowOther` REMOVED — git archaeology: added Feb 2026 (e117266) alongside then-active WinApps (the FUSE consumer, gone since 26.05 migration); zero `allow_other` consumers today; zcode AppImage runs via bwrap.
- lix substituter + key removed from core/nix.nix (lix comes from nixpkgs; nix-community cachix covers lixPackageSets... actually cache.nixos.org does).
- README rewritten (shallow + collapsed fold-outs, Lix badge 2.94); REPO_OVERVIEW jan refs fixed; opencode.yml newline.

**Still pending (user decision/operator work):** latitude + nix-media sops re-encryption ([[sops-identity-architecture-2026-09-13]], SOPS_RUNBOOK §3).

Related: [[repo-audit-2026-09-09]], [[yoga-hibernate-status]].
