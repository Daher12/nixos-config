---
name: audit-fixes-2026-11-15
description: Repo audit verdict + executed hygiene round (doc rot, persistence
  gaps, swapfile/fleetKeys dedup, sudo 15, trustedUsers narrowing) — fast+VM
  green, UNCOMMITTED
metadata:
  node_type: memory
  type: project
  originSessionId: sess_432505d6-947f-4168-bdb5-db72b9e8e692
---

Audit 2026-11-15 (main @ 555ba56): fleet verdict GOOD — all three devices genuinely optimized for their use cases (yoga power stack layered + live-verified; latitude maintained via shared modules, not rotting; nix-media QSV/resource-governance/lifecycle excellent). No dead modules, no functional hyprland remnants. Executed the selected hygiene round same day; everything UNCOMMITTED in working tree (staged: lib/keys.nix, modules/features/swapfile.nix).

**Why:** dedup residue + doc rot were the only real findings; user picked P1 docs, P1 persistence (Grafana secret_key → sops EXPLICITLY SKIPPED), P2 dedup+posture (sudo 30→15 chosen), and host-units-smoke VM only.

**How to apply:**
- New: `modules/features/swapfile.nix` (features.swapfile.enable/sizeMiB/device → swapDevices; yoga 16G, latitude defaults), `lib/keys.nix` → `fleetKeys` specialArg wired in mkHost commonArgs (latitude+nix-media authorizedKeys use `fleetKeys.dk-yoga`; both host headers declare it).
- `core.nix.trustedUsers` option (default root+mainUser; nix-media narrows to [ "root" ]); journald `SystemMaxUse=200M` mkDefault in core/systemd.nix (hosts override wholesale); sudo default 15.
- Yoga persistence: `.local/share/onlyoffice`, `.local/state/zcode` added — land with the pending gen-202 switch.
- LORE: module specialArgs must be DECLARED in the consuming module's header — `.#nixosConfigurations.*.pkgs...` eval fails with "undefined variable" otherwise; tests that mirror mkHost ([[test-suite-shared-runner-2026-11-01]] host-units-smoke) must mirror NEW specialArgs too (VM test caught the missing fleetKeys mirror).
- LORE: `nix eval --json ...config.swapDevices` dies on a lazy `label` attr ("accessed but has no value") — use `--apply 'map (s: { device = s.device; size = s.size; priority = s.priority; })'`.
- BEFORE-eval trick: with a clean index, background `nix eval` snapshots the pre-edit tree; but tracked working-tree edits ARE visible to new evals (only NEW files need staging).
- Doc facts: docker_29 pin row in REPO_OVERVIEW was aspirational (git -S empty; nixpkgs ships docker 29.9.3); AGENTS.md wrap example fixed to home/opencode.nix; spotx row no longer cites revs (they rot — flake.lock is the source).
- Parallel session edited hosts/nix-media/docker.nix (StartLimit* → top-level [Unit] keys fix) mid-session — left unstaged, NOT mine (see [[parallel-index-work]]).
