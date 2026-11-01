---
name: update-sweep-plan-2026-10-16
description: 2026-10-16 full update audit — all pins vs upstream measured;
  7-phase sweep plan built, user approved scope "everything incl. lucid
  v1.20.1", ExitPlanMode DENIED → nothing executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e8363ef5-bfaa-4cd2-90ad-ff42521163c8
---

Full update audit 2026-10-16 (read-only, plan mode). Nothing executed — the final
ExitPlanMode was permission-denied, so the sweep is PLANNED + scope-approved only.

**Audit results (locked rev → upstream, all via git ls-remote/npm, verified):**
- OUTDATED infra: nixpkgs 26.05 `7c8764b`(10-08)→`26f4107`; home-manager `db7d5e2`→`32904df`; sops-nix→`4493170`; nixos-hardware→`60a6244`. Clearable via update-safe set.
- OUTDATED manual pins: **opencode v2.0.26 → v2.0.31** (tag pin, bump = edit ref in flake.nix ~L42-55 + `nix flake update opencode`; releases 27–31 have placeholder notes, no breaking changes); **mikromcp 1.13.1 → 1.14.0** (npm registry src in pkgs/mikromcp.nix, has checked-in mikromcp-package-lock.json + npmDepsHash → fakeSha256 hash dance); **dank-greeter `334b2c9`(09-27) → `a8b1063`** (22 commits, mostly fixes: session-list, XDG/NoDisplay precedence, launcher -p boot-loop fallback, Go 1.27, qml-common bumps — low risk); **lucid `e662954`(v1.20) → `8bc32666` = v1.20.1 (rel. 10-15) + 4 newer commits** — 52 commits/177 files incl. fingerprint unlock, XDG-autostart settings page, live wallpapers, and "Theme: follow the wallpaper into light or dark" which OVERLAPS our lucidAutoMode apps-auto/shell-dark work (watch for double theme-switching post-bump).
- CURRENT, no action: quickshell 0.3.2 (locked rev == master HEAD == latest tag), lanzaboote v1.2.0 (tag still matches), disko, impermanence, preload-ng, flake-compat.
- zcode 3.14.5: no discoverable upstream listing (CDN binary); established technique = ranged-GET probe of candidate version URLs.
- Transitive crane/rust-overlay/git-hooks/flake-utils/systems: moved but deliberately skipped (only refresh with lanzaboote/preload-ng).

**Approved plan (7 phases, user chose "Everything incl. lucid"):**
1. `scripts/update-safe yoga` (build-only default) + dry-build latitude/nix-media + Hyprland ≥0.55.6 floor check via `nix eval .#nixosConfigurations.yoga.config.programs.hyprland.finalPackage.version`.
2. opencode ref → v2.0.31 + `nix flake update opencode` (its nested nixpkgs_2 refreshes automatically).
3. mikromcp → 1.14.0: prefetch-file hash + regenerate package-lock from tgz + fakeSha256 npmDepsHash round-trip via toplevel build.
4. zcode CDN probe (3.14.6/3.14.7/3.14.8/3.15.0 ranged GETs).
5. `nix flake update dank-greeter` + dry-build (live-verified only next boot).
6. lucid via LUCID_RUNBOOK §2 Scenario A P0–P7, LAST; offset-fuzz likely; update runbook Appendix B pins table + REPO_OVERVIEW after.
7. Final QC: fmt, stage, flake check, dry-builds ×3, NO commit; hand user the switch command.
Guards: expect `git status` to show only M REPO_OVERVIEW.md + M home/hyprland.nix + ?? .zcodeignore at start; update-safe `git pull --ff-only` may fail on unpushed local commits → stop.

Related: [[manual-pkg-updates-2026-10-10]] (prior round), [[plans-for-weaker-executor]] (plan written self-contained for handoff).
