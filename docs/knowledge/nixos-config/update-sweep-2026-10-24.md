---
name: update-sweep-2026-10-24
description: Executed update sweep — all pins except lucid (held); opencode
  v2.1.4, mikromcp 1.14.1, dux-greeter rename; API-403 flake.lock jq-patch
  technique
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7ebaa868-7ab4-49a5-97c3-abbdb3912f78
---

Update sweep 2026-10-24: EXECUTED + QC green, STAGED, no commit/switch (house rules). Rollback snapshot: /tmp/flake.lock.pre.

Bumped: nixpkgs 26f4107→da6dc0e (26.05), home-manager→24f8f8e, sops-nix→e80b8b7, nixos-hardware→1b418b8, disko→cedd626, impermanence→fa627f4, spotx-nix→5e300d4 (spotx-bash 2ebfe88), opencode v2.0.27→**v2.1.4** (upstream fileset bug fixed in 3171839709, 2026-10-19, first in v2.1 line — direct `nix build` of their package verified clean; nixpkgs_2 stays 3181085 = their own pin), quickshell 2b4501a→9b0f339 (patch 201 dry-run APPLIES; master still declares VERSION 0.3.2), mikromcp 1.14.1 (tarball hash s06iNA…, npmDepsHash wpjFNyZ…), **dank-greeter renamed** AvengeMedia/dank-greeter→duxlabs-dev/dux-greeter @920def3 (+ dank-qml-common→duxlabs-dev @794dfc9; owner updated in flake.nix, REPO_OVERVIEW, LUCID_RUNBOOK, desktop-hyprland.nix comment).

HELD: lucid at 8bc3266 — deliberately deferred until staged perf round 122-125 is switched and idle-CPU re-measured (see [[lucid-perf-round-122-125-2026-10-17]]). lanzaboote v1.2.0 + preload-ng current.

**flake.lock jq-patch technique** (GitHub API 403 = unauth 60/hr exhausted): resolve refs via `git ls-remote` (git protocol, no API), `nix flake prefetch github:o/r/<rev> --json` (codeload, no API; Lix returns {hash,storePath} — `hash` IS the lock narHash), lastModified via depth-1 `git fetch` + `log -1 --format=%ct`, then jq the node's `locked` {rev,narHash,lastModified}. ⚠️ lock `locked` must NOT carry `ref` (only `original` does) — "has both ref and rev" validation error. Child nodes: mirror the parent's own flake.lock at the new rev (opencode's nixpkgs pin unchanged → nixpkgs_2 untouched).

s2h harness (tests/s2h-harness.sh) is sandbox-blocked: hardcodes /run/yoga-s2h-* writes, sandbox denies /run → 47/63 spurious FAILs. Files unchanged since the 59/59 pass ([[yoga-hibernate-status]]). Do NOT disable sandbox to run it — that writes stubs into LIVE s2h state.

QC green: nix flake check, dry-builds yoga/latitude/nix-media, host-units-smoke VM test, opencode direct build, mikromcp build, patch-201 dry-run.

Pending: user switch → smoke: opencode launch, greeter login once, Spotify launch, restart lucid (quickshell moved) + redo idle-CPU measurement → THEN lucid bump (57 commits waiting, [[repo-review-2026-10-16]] pattern).
