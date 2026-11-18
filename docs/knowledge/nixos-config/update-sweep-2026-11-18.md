---
name: update-sweep-2026-11-18
description: Pkg bump sweep EXECUTED+pushed (03f5a7c lock + d0ec6c7) — zcode
  3.18.1, fastmcp override REMOVED (dead code), opencode v2.3.x all gate-fail;
  zen kernel 7.2.15→7.3.4 rides the nixpkgs bump
metadata:
  node_type: memory
  type: project
---

Update sweep executed 2026-11-18 (plan approved via AskUserQuestion: full sweep, opencode gate-with-fallback, update-safe --push, fast gate only / VMs skipped). Two commits, both PUSHED: **03f5a7c** (flake.lock inputs, update-safe pathspec commit) + **d0ec6c7** (zcode, flake.nix comment + fastmcp removal, REPO_OVERVIEW). QC: `test-suite fast` green (yoga latitude nix-media) + update-safe's real yoga toplevel build (1057 derivations).

**Bumped (flake.lock, via `scripts/update-safe yoga build-only --push`):** nixpkgs f1e5c356→**f684076** (2026-11-16), home-manager 6eb2d33→**5643e73** (11-17), sops-nix 11e5885→**7c637af** (11-16), nixos-hardware eb3c90b→**3347596** (11-18). disko/impermanence/preload-ng unchanged. **Kernel rider: linux-zen 7.2.15→7.3.4** — flag for the user's next switch (reboot territory); ryzen-smu override (pinned d298366, "Fix cpuid include on 7.2+") compiled clean against 7.3.4. nixpkgs ryzen-smu itself still 2025-10-22, so the override stays. spotify-spotx built green inside update-safe → no SpotX-Bash drift this nixpkgs bump.

**Vendored pkgs:** zcode 3.17.2→**3.18.1** — discovery method: CDN URL-pattern HEAD probes (`ZCode-3.18.1-linux-x64.AppImage` → 200, 3.19.0 → 404), hash via `nix store prefetch-file`. mikromcp 1.16.1 still npm-latest. colloid rev fe11342 = HEAD, fluent rev c8a244f = HEAD (verified via api.github.com /commits/main).

**opencode: PIN HELD at v2.2.4.** v2.3.0, v2.3.1, v2.3.2 ALL gate-fail (`nix build github:anomalyco/opencode/v2.3.N`) with the SAME stale node_modules hash (specified `sha256-UOVs48Z4…` matches none of the three shipped lockfiles; got zOej…/At90…/At90…) — upstream's vendored hash hasn't been regenerated since 2.2.4, six consecutive broken releases. Recorded in the flake.nix comment + REPO_OVERVIEW pins table. Gate exits were read un-piped (`GATE_EXIT=${PIPESTATUS[0]}`) per the 11-12 lesson.

**fastmcp doCheck override REMOVED (dead code).** Findings: (1) nixpkgs f684076 ships `python313Packages.fastmcp` with `doCheck = false` upstream (nix eval proof) — the "skip the suite so the package builds" rationale is obsolete; (2) `python313.override { packageOverrides = … }` no longer re-derives the package set on 26.05: `interpreter.pkgs` re-exports the top-level `python313Packages` set, so `overridePythonAttrs { doCheck = … }` never lands anywhere reachable (isolated getFlake test: base=false, viaPkgs=false even with the override applied). The block still changed derivation hashes (interpreter .override bakes its args in — pre-removal closure had fastmcp cbg450zi/mcp-nixos 78yk7ng, stock is xnnj8ia/qncfinmi), so removal reverts yoga's python set to stock nixpkgs — behavior-identical content-wise, nothing else consumes python313 directly (grep: only `pkgs.mcp-nixos`, which comes from python313Packages). NOTE: the fastmcp pytest suite itself was never re-run — doCheck=false everywhere means nothing runs it; revisit only if nixpkgs re-enables checks upstream.

**Held per policy (verified still-newest via tags pages/API):** noctalia v5.5.0 (Nov 12), noctalia-greeter v1.7.0, lanzaboote v1.2.0 (CI-dispatch only), spotx-nix (reactive only). Update-safe refused nothing; tree clean at start.

User steps: `nus yoga` / `sudo nixos-rebuild switch --flake ~/nixos-config#yoga` when ready (also activates the still-staged noctalia/GTK/auto-light-dark work from 11-15…11-18); kernel 7.3.4 needs the next reboot to take effect.
