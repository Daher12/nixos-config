---
name: update-sweep-plan-2026-10-31
description: Update sweep 2026-10-31 recon+plan (ExitPlanMode DENIED, NOTHING
  executed) — lucid onto declared beta approved by user, zcode included; full
  bump table with revs
metadata:
  node_type: memory
  type: project
  originSessionId: sess_6c2908a5-cb4f-4fa6-88ce-a202f3885328
---

Update sweep 2026-10-31, plan-mode only (ExitPlanMode denied → NOTHING executed). "pkg bump, same as usual" = the [[update-sweep-2026-10-28]] recipe. Supersedes nothing; successor record should supersede this file.

Measured drift vs upstream (2026-10-31):
- nixpkgs nixos-26.05 718f670e → 6f06d204; nixos-hardware → 04c6b94f; spotx-nix → 070132b6; dux-greeter → 45b82d84 (qml-common rides transitively)
- **opencode v2.2.0 → v2.2.5** (5 patch tags; standing gate: `nix build github:anomalyco/opencode/v2.2.5` clean BEFORE tag edit; nixpkgs_2 follows the tag's own lock)
- **zcode 3.14.5 → 3.16.3** (user APPROVED inclusion; CDN probes: 3.14.6/3.14.7/3.15.0 = 404, 3.15.1/3.15.3/3.16.2/3.16.3 = 206; last two sweeps had silently skipped zcode)
- **lucid 4b8fc9a → 2945eab**: 17 commits / 205 files — Lumen file manager, Lens image viewer, LucidShot rebuild, edit mode, new tonal icon set, Poster clock face, Jelly motion; upstream marks HEAD as BETA ("Lucid 1.20.5.5, a beta"). User APPROVED bumping onto the beta (rule "no quickshell release in sight → bump lucid" fired: v0.3.2 still newest, no release-prep commits, PR #1049 still open+dirty). Expected patch hot spots: Clock.qml (116/126), System.qml (104/114/122), Dock.qml+icons (001), shell.qml (125), Mpris (122); Lumen/Lens may add stateFiles + runtime deps.
- Unmoved: home-manager, sops-nix, disko, impermanence, preload-ng, quickshell (pin 9b0f339 == tip), mikromcp (npm latest == 1.16.0)

Plan as approved: snapshot flake.lock to /tmp → opencode gate+bump → flake inputs → zcode (pkgs/zcode.nix ver+hash) → lucid Scenario A P0–P7 (wallpapers /tmp-2GB gotcha) → nix fmt+git add → QC (flake check ×2, dry-builds yoga/latitude/nix-media, host-units-smoke VM test, closure checks opencode/qs-wrapper/zcode) → docs sync (runbook Appendix A/B + REPO_OVERVIEW pins) → stage only, never commit → memory + §7 report (smoke list incl. NEW surfaces Lumen/Lens/LucidShot/edit mode; `systemctl --user restart lucid` mandatory).

Lore: plan mode blocked even plain `git ls-remote` bash in main shell (not just writes) — fresh Explore agent ran all network probes fine (ls-remote, GitHub API, npm registry, zcode CDN ranged-GET).
