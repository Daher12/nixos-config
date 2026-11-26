---
name: lean-mean-audit-plan-2026-11-26
description: Full "Lean and Mean" repo audit 2026-11-26 (main @ 8e40ccb) — plan
  built (measure step + batches A–E), ExitPlanMode DENIED, NOTHING executed,
  eval timings NOT taken
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7d1188e6-bb26-4042-a067-47da5fe0ef95
---

User asked 2026-11-26 for a repo audit "anything goes … Lean and Mean" + wiring best practice + "is eval time justified". Plan mode; `nix` and (mostly) `git` are blocked for the coordinator in plan mode, so no timings exist. Three Explore agents (wiring / bloat / hygiene), claims hand-verified against nixpkgs 26.05 at `/nix/store/s9ai2k29jw25mk3xnbvl0j233ybc9rrm-source`. Nix on yoga = Lix 2.95.4.

**Verdict:** wiring sound (one `nixosSystem` site, HM on global pkgs, one overlay stage, 11 inputs all used, no orphans, one TODO). Findings are a long tail plus five that matter:

1. `--impure` on every verification path (`scripts/test-suite:85,92`, `update-safe:111`, `ci.yml`, `bump.yml`) — from my reading of the evaluator this disables the eval cache (pure mode only); UNMEASURED hypothesis, no doc explains the flag (inherited 2026-10-19).
2. Hosts evaluated twice: `nix flake check` then dry-build loop (README says check evaluates all hosts; unverified for Lix).
3. Grafana `secret_key` plaintext in `hosts/nix-media/monitoring.nix:271` + `REPO_OVERVIEW.md:437` (comment: "intentionally hardcoded").
4. `scripts/export-zcode-memory` has no allowlist → 3 UUID-named folders with unrelated personal notes tracked in `docs/knowledge/`; mirrored MEMORY.md 28.7KB > 24.4KB loader limit (25 entries dropped).
5. `home/theme.nix` installs Colloid + 3 switch-theme scripts + `.themes` on the niri host where darkman is disabled.

**Plan (not executed):** Step 1 measure (cold / warm pure / `--impure` per host, `nix flake check --no-build`, whole `fast`); A tooling (drop `--impure`/`--all-systems`, one dry-run, CI reuses test-suite, bump.yml format-before-verify, fix `suggest` profiles→host-units-smoke over-claim); B `modules/core/nix.nix` (drop `max-jobs`/`cores`/`sandbox`/`auto-optimise-store`, duplicate cache.nixos.org + key, `root` in trustedUsers, `builders-use-substitutes`, `nix.registry`/`nixPath` — all covered by nixpkgs `config/nix.nix` + `misc/nixpkgs-flake.nix`; drop dead `extraSpecialArgs`); C output-changing (theme gate, `nix.channel.enable = false`, per-attr persistence gating on yoga, ~30 default-restating one-liners in 12 files, drop `fira-code`/`roboto`); D Grafana key → sops side file (user-run, rotate); E hygiene (allowlist, compact memory index, doc fixes, wrong comments, `.gitignore` prune).

**Proof design:** `nix eval --json` record of affected values before/after, byte-identical → no VM battery. Toplevel drvPath identity is NOT usable as proof (any source edit changes the flake source hash).

**Why:** user wants a lean config; plan is ready to execute on request.
**How to apply:** if the user says "execute plan", start with the measurement step and report numbers before edits; open question = whether live `/etc/nix/registry.json` lacks `self` entry despite config declaring it (check with `nix eval …config.nix.registry`). Pushing main auto-deploys nix-media at 05:00. Left alone on purpose: 4 nixpkgs trees in lock, vendored opencode-skills, mnamer tooling, Silo, `.gnupg` persistence (only pubring + trustdb on disk). Related: [[audit-fix-round-plan-2026-11-18]], [[test-suite-shared-runner-2026-11-01]], [[sops-hygiene-verified-2026-11-25]].
