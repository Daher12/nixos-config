---
name: quickshell-packaging-eval-2026-09-30
description: Measured eval of quickshell source=unstable=stable options — 4min
  local build, eval-time "double nixpkgs" is a myth (0.3s), version floor
  decides
metadata:
  node_type: memory
  type: project
  originSessionId: sess_313723d6-135d-460a-85f9-fed092ed1bed
---

Evaluated 2026-09-30 for the quickshell input switch (nixpkgs-unstable → upstream flake `github:quickshell-mirror/quickshell` follows nixpkgs-26.05). Verdict: keep the upstream flake.

**Measured facts (yoga, Ryzen 7 6800HS, ninja -j16):**
- Quickshell 0.3.1 local compile = **4m12s** (2026-09-30, 595 CXX units, 13:25:56→13:30:08); corroborating datapoint 3m45s on 2026-09-21. Not hours — per-bump cost is a coffee break.
- Full `nix eval .#nixosConfigurations.yoga...toplevel.drvPath`: old config (2× nixpkgs via nixpkgs-unstable) **22.65s** vs new (1× nixpkgs) **22.34s** warm. The "double eval time" concern is a **non-factor** (~0.3s) — lazy attr access doesn't force the whole unstable package set. The REAL reasons to drop unstable: quickshell docs' follows-mandate (unstable quickshell links unstable Qt into a 26.05 session = documented crash class) + version control vs the lucid floor.
- Live channel versions 2026-09-30: **26.05 = quickshell 0.3.0 (BELOW the 0.3.1 floor in home/lucid.nix), unstable = 0.3.1**, upstream = 0.3.1+ (pin rev 41651d7d). Stable is not viable without lowering the floor and re-testing the lucid/greeter pairing.
- The mcp-nixos index was STALE (claimed 0.2.1 in both channels) — always confirm versions with a live `nix eval github:nixos/nixpkgs/<channel>#quickshell.version`.

**Rebuild triggers for the from-source quickshell:** manual pin bump (`nix flake update quickshell`) or any Qt6/stdenv change in 26.05 arriving via update-safe nixpkgs bumps — a handful of 4-min compiles per year. Unstable was NOT compile-free either: 2026-09-21 hydra lag on a fresh unstable pin forced the same local build. No binary cache exists for the upstream flake (docs + flake.nix confirm: no nixConfig substituters).

**Timing trick:** store mtimes are epoch-normalized; real build start/end = birth/mtime of `/nix/var/log/nix/drvs/<2>/<rest>.drv.bz2`.

**GC caveat:** a dry-build/build result is unrooted — GC before `switch` deletes the 4-min artifact and forces a recompile. After switch it's in the system closure.

**QML-module mechanism (learned 2026-10-10, lucid v1.20 Qt5Compat crash):** quickshell's `bin/qs` is a makeQtWrapper **C wrapper** (ELF, not a shell script) baking `--prefix NIXPKGS_QT6_QML_IMPORT_PATH <qml-dir>` args into the binary — runtime env overrides cannot safely extend that list. The designed extension point is the `withModules` passthru (default.nix:150): `quickshell.withModules [ qt6.qt5compat ]` = `wrapper.overrideAttrs (buildInputs ++ modules)`, and wrapQtAppsHook folds the Qt modules' qml dirs in. Costs ZERO recompiles — only the wrapper derivation re-derives (inner `.quickshell-wrapped` sha256-identical before/after). ⚠️ withModules does NOT accumulate across chained calls (`.withModules [a].withModules [b]` drops [a] — the lambda anchors on the base wrapper); pass ALL modules in ONE list. In this repo: flake.nix overlay carries it for lucid v1.20, which imports `Qt5Compat.GraphicalEffects` (lucidbar/Workspaces.qml, lucidui/ShapedImage.qml; upstream lists qt6-5compat as a hard requirement, Arch ships it system-wide). Runbook failure-playbook has the generalizable row.

Related: [[lucid-hardening-quickshell-flake-2026-09-30]], [[lucid-buildtime-patches-2026-09-28]], [[lucid-cleanup-dms-removal-2026-09-27]], [[lucid-v120-minimal-bump-2026-10-09]]
