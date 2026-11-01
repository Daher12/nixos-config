---
name: repo-docs-comments-audit-plan-2026-10-18
description: Repo-wide docs/comment hygiene plan 2026-10-18 — audits done, user — SUPERSEDED: EXECUTED same day, see docs-comment-hygiene-pass-2026-10-18
  approved all 4 code fixes, ExitPlanMode DENIED → NOTHING executed; full fix
  inventory inside
metadata:
  node_type: memory
  type: project
  originSessionId: sess_4f5fc882-9b0c-4960-a17f-aaf84af5b0ab
---

Repo-wide comment/documentation audit + cleanup plan, 2026-10-18. Three Explore audits completed (docs freshness, comment hygiene across all 77 .nix files, install.sh/pins/spotx). User approved ALL four optional code fixes via AskUserQuestion. **ExitPlanMode DENIED → NOTHING executed.** Base: clean tree @ `1d6a7b7` (parallel session committed the spotify staging as 44b405f + quickshell bump; quickshell now 0.3.2 @ `2b4501a2`). No commits in plan — stage only, per [[parallel-index-work]].

**Key audit findings (verified, still-unfixed):**
- DANGEROUS stale: LUCID_RUNBOOK.md §5 troubleshooting row tells executor to fix missing Qt modules via upstream `withModules` — this would silently discard the 201 engine patch (flake.nix:153-161 warns exactly this). Correct remedy: add module to replicated wrapper's `buildInputs` in flake.nix overlay.
- LUCID_RUNBOOK Appendix B: quickshell rev stale (`4f508be5` → `2b4501a2`, 0.3.2, 2026-10-18); `:54` lucidPatched pointer 26→44; P3 refs retired patches 002/107 → 113-119.
- REPO_OVERVIEW.md: `:5` Last-updated 2026-10-04; `:144` still describes withModules overlay (abandoned 2026-10-10); `:381/386` lucid "v1.10.5 @ 09820bb" + "9-patch layer" (actual v1.20.1 @ 8bc32666, 15 patches; 119/121 never mentioned).
- README.md: `:73-74` claims hibernation parked (WORKING since 2026-10-18, see [[yoga-hibernate-status]]); docs table missing LUCID_RUNBOOK.md/AGENTS-global.md; dir map missing lucid layer + quickshell-patches + virbr0 test; `:193` locked list incomplete (6 actual: lanzaboote, opencode, quickshell, dank-greeter, lucid, spotx-nix).
- AGENTS.md + SOPS_RUNBOOK.md: missing `secrets/hosts/nix-media-litellm.yaml`.
- flake.nix:67 stale "v1.10.5 … 0.3.1 floor" (actual minQuickshell 0.3.2); "one nixpkgs eval" claims ×3 contradict opencode's own nixpkgs_2 (scope to "NixOS/desktop stack").
- Comment hygiene: 2 commented-out code sites (yoga:226 initcall_blacklist, nix-media:52 configurationLimit); ~10 stale one-time instructions/tombstones (laptop.nix:53-54, yoga/home.nix:172-179+rmdir, latitude/disks.nix:13-19 adoption, opencode.nix orcarouter, DMS tombstones ×2, docker.nix DOCKER_MODS); duplicated stories to consolidate (DMS cluster hyprland.nix, s2h ×3, hyprctl-eval ×2, theme "single source" ×2); missing why-comments: mikromcp srcWithLock dance, lanzaboote pin rationale, spotify.nix pin-drift pointer.
- install.sh: 3 of 4 Sept-2026 breakages already FIXED (nix-eval detection, sops identity, key.txt); remote-clone-by-design w/ REPO_URL hatch. NEW bug: hardcoded USER_UID 1000 chown vs nix-media dk uid 1001 → wrong ownership on fresh install. SpotX gotcha already documented (flake.nix + REPO_OVERVIEW:544).

**Approved plan (A–G):** A comment cleanup ~25 nix files (list above + banners, keep load-bearing incident comments); B 4 LUCID_RUNBOOK fixes; C REPO_OVERVIEW updates + NEW "Manual pins & manual packages" section (opencode v2.0.28+ unbuildable + tag recipe, mikromcp bump recipe = version+2 hashes+lockfile, lanzaboote CI dispatch toggle, pointers to runbook/spotx gotcha); D README fixes; E AGENTS/SOPS/INDEX litellm + tests/ + quickshell-patches/; F all 4 code fixes (install.sh uid via nix_eval, biweekly-reboot→weekly-reboot rename, rm yoga local-passwords tmpfiles rule :322, rm -rf .Trash-1000); G QC: re-check git status, `nix fmt <files>`, git add, flake check, dry-build yoga+nix-media, bash -n install.sh.

Related: [[plans-for-weaker-executor]] (plan is self-contained in this file), [[lucid-runbook-2026-10-08]], [[install-sh-audit-2026-09-17]].
