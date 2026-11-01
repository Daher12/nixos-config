---
name: update-sweep-plan-2026-10-27
description: Update sweep 2026-10-27 recon+plan (ExitPlanMode DENIED, NOTHING
  executed) — quickshell at tip/no release in sight → lucid INCLUDED; full bump
  table with revs
metadata:
  node_type: memory
  type: project
  originSessionId: sess_3bff24fb-b64d-40fe-acd2-a0b246ed7e0b
---

Update sweep 2026-10-27: plan-mode session, full pin-vs-upstream recon done (Explore agent, git ls-remote + GitHub pages + npm), plan written, **ExitPlanMode DENIED — NOTHING executed**. User rule: bump everything including lucid IF no quickshell update in sight, else postpone lucid.

**Decision input (verified):** quickshell pin `9b0f339b` IS master tip (mirror + git.outfoxxed.me identical); newest release still v0.3.2 (2026-10-08), master only 11 bugfix commits past it, no version bump/changelog/release-prep; cadence ~7 weeks, only 2.5 elapsed; disk-cache PR #1049 still OPEN (patch 201 still required). → **lucid bump proceeds**.

**Planned bumps (full revs):**
- nixpkgs nixos-26.05 `da6dc0e7`→`718f670e845328e9c2cecdd832835712b2cbd065` (10-26) — pin is on STABLE 26.05, not unstable
- nixos-hardware →`8ba09466dc929acf5c8bb3e0cc40f472a7df3630`; home-manager release-26.05 →`24f2190587513b9c2f73db112a17844ae912d965`; sops-nix →`60182817ee048ac94b4c68ea76d5ef2e8aac730d`
- dux-greeter `920def34`→`0f5de0577cc118091cab9ed8d7976919f0161251` (6 commits, no new tag; pinned rev already contains v2.0.0 rebrand — flake.nix "DankGreeter 1.6.2" comments stale)
- spotx-nix →`54f055db9c1bf60224a060bf3e289f23719edc01` (after nixpkgs)
- opencode v2.1.4→**v2.2.0** `1097e2668b1e08ad63bdf0b1c4860b9bc01e420c` (released 2026-10-27 same day; owner anomalyco; gate-build FIRST — v2.0.28–v2.1.3 unbuildable precedent)
- mikromcp local pkg 1.14.1→**1.16.0** npm (repo AliKarami/MikroMCP; vendored package-lock.json must be re-fetched at new tag)
- lucid `8bc32666`→`4b8fc9a450683795ddfb1764cc92fb282f14f75a` (10-20, 57 commits, still no tag after v1.20.1) — LUCID_RUNBOOK Scenario A
- NO action: quickshell/disko/impermanence/preload-ng (at tip), lanzaboote (tag-pinned by policy)

**Lucid-jump risks:** (1) NEW self-updater + beta channel at tip — policy decided: Nix owns updates; manual Settings button → document don't-click, auto-by-default → guarded lucidSync prefs migration (ambientMotion pattern) or patch-disable; (2) stateFiles gate likely trips (updater state → P4); (3) upstream REMOVED Chip/Accent bar looks (consolidation) — prefs referencing them falls back; (4) expected patch churn: Clock 116/118/126, Agenda 118/127, WifiPanel 114/129, Lockscreen 113/128, notifs 117, System 104/114, Prefs/shell.qml 122/125, Mpris/Cava 123; (5) media panels PR #89, mirroring PR #86 churn in same areas. minQuickshell stays 0.3.2.

Procedural notes: per-input `nix flake update <input>` (not bare), spotx-nix LAST; API-403 fallback = jq-patch technique in [[update-sweep-2026-10-24]]; mikromcp build via `nix build $(nix eval --raw .#nixosConfigurations.yoga.pkgs.mikromcp.drvPath)`; QC = flake check + dry-build 3 hosts + optional host-units-smoke; stage, no commit. Execution status unknown — if a later session executed this, supersede with an execution record.
