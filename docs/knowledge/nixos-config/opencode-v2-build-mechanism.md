---
name: opencode-v2-build-mechanism
description: opencode 2.x build route evaluated 2026-10-05 — upstream flake
  source build is the ONLY option (no release binaries, no npm, no cache);
  bumped to v2.0.23, postInstall override dropped
metadata:
  node_type: memory
  type: project
  originSessionId: sess_bbde4f33-55c0-4390-8e78-a624226e79bf
---

Evaluated 2026-10-05 how opencode 2.x must be obtained (user asked if a better mechanism exists; verdict: no):

- **2.x ships NO prebuilt artifacts anywhere**: no GitHub Releases (releases page only has v1.18.x), no npm (`opencode-ai@2.x` 404s; npm latest = 1.18.34), no upstream binary cache/substituters. Only git tags. So fetchurl+autoPatchelf is impossible; upstream flake source build (bun node_modules FOD + compile) is the only route.
- **nixpkgs stuck on 1.x**: 26.05 = 1.15.10, master = 1.18.34 (packages/opencode layout). Cannot satisfy Obsidian Copilot's 2.0.3+ floor.
- **Current wiring**: flake input `github:anomalyco/opencode/v2.0.23` (rev 0fd7e282, no `nixpkgs.follows` — upstream's own unstable pin supplies bun 1.4.2; 26.05's bun 1.3.13 hangs). Override in `home/opencode.nix` is now ONLY the libstdc++ `--prefix LD_LIBRARY_PATH` wrap (postFixup append). The v2.0.22-era `postInstall = ":"` hack was DROPPED — v2.0.23 fixed completions upstream via global `--completions bash|zsh|fish` flag (verified live: script output).
- Bump procedure that worked: edit tag in flake.nix → `git add` (index, not worktree) → `nix flake update opencode` → `git add flake.lock` → build `programs.opencode.package` (~5 min local) → smoke `--version` + `--completions bash` → home-files diff for settings.
- Note: `nix flake update opencode` also refreshes upstream's nested nixpkgs_2 node (whatever their flake.lock pins) — expected, don't chase the date.
- 2026-10-06 status: the v2.0.23 bump was COMMITTED in 5df41f6 ("yoga: damp iwd band-flapping, opencode v2.0.23"); user switch still pending.
- Recheck at next bump: whether v2.0.23's `--completions` postInstall survives, and whether releases/npm appear (would enable cheap fetchurl derivation instead of source build).

Related: [[obsidian-litellm-integration]] (Copilot floor is the reason for the v2 pin).
