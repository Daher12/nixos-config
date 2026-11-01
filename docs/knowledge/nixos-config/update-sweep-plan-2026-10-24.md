---
name: update-sweep-plan-2026-10-24
description: Pin-vs-upstream audit 2026-10-24 + approved sweep plan "all but
  lucid" — ExitPlanMode DENIED, nothing executed; full diff table +
  repo-transfer facts inside
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7ebaa868-7ab4-49a5-97c3-abbdb3912f78
---

2026-10-24 update audit (plan mode). User chose scope "All but lucid" (lucid deferred until staged perf round [[lucid-perf-round-122-125-2026-10-17]] is switched + re-measured). ExitPlanMode DENIED → NOTHING executed; plan ready to re-run.

Behind (locked → upstream as of 2026-10-23): nixpkgs 26.05 26f4107→da6dc0e (+415c), HM 32904df→24f8f8e, sops-nix 4493170→e80b8b7, nixos-hardware 60a6244→1b418b8, disko 725ea35→cedd626 (32d), impermanence 7b1d382→fa627f4, spotx-nix 77b1def→5e300d4 (+bash 2ebfe88), quickshell 2b4501a→9b0f339 (master-rolling; patch 201 gate), mikromcp 1.14.0→1.14.1, opencode v2.0.27→v2.1.4 (508c; blocker FIXED — upstream 3171839709 2026-10-19 ships ../script to CLI build, first in v2.1 line; rewrite flake.nix:51-55 comment, keep LD_LIBRARY_PATH wrap, home/opencode.nix has NO postInstall to drop), lucid 8bc3266→4b8fc9a (57c/4d, self-update+beta-channel landing — deferred), dank-greeter repo TRANSFERRED AvengeMedia→duxlabs-dev/dux-greeter (920def3; rename owner in flake.nix:89). lanzaboote v1.2.0 + preload-ng current.

Plan phases: per-input `nix flake update` + /tmp/flake.lock.pre snapshot for per-input rollback; spotx loud-fail contingency; mikromcp refetch BOTH hashes; QC = git add → nix fmt (explicit files) → flake check → dry-build yoga/latitude/nix-media → opencode.json byte-diff → s2h harness + host-units-smoke VM test. Stage 47 existing files untouched. Post-switch: opencode --version, greeter login, spotify, restart lucid, THEN idle-CPU re-measure (engine moved).

Durable facts: opencode repo now anomalyco/opencode (transferred from sst); nixpkgs main = nixos-26.05 (single eval; opencode's private nixpkgs_2 unstable is the only second); flake.lock is committed+clean, 47 files staged pending switch. See [[update-sweep-2026-10-16]].
