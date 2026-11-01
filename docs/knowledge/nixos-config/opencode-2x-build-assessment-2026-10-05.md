---
name: opencode-2x-build-assessment-2026-10-05
description: opencode 2.x pinning assessed OPTIMAL 2026-10-05 (2.x ships no
  releases/npm/cache — git tags only); v2.0.23 fixes completions so postInstall
  override drops at bump; bump handoff delivered to executor, outcome unknown
metadata:
  node_type: memory
  type: project
  originSessionId: sess_bbde4f33-55c0-4390-8e78-a624226e79bf
---

Assessment 2026-10-05 (plan mode), triggered by "check how the opencode 2.0.22 build is handled (it works right now) or if there's a better way".

**Mechanism (staged, working):** flake input `github:anomalyco/opencode/v2.0.22`, deliberately NO `nixpkgs.follows` (upstream's own nixpkgs-unstable pin supplies bun 1.4.2; 26.05's bun 1.3.13 hangs on `bun install` of the 2.x native tarballs). `home/opencode.nix` overrides: `postInstall = ":"` (v2.0.22 upstream generates completions via a REMOVED `completion` subcommand → ENOENT build abort; verified upstream postInstall contains completions ONLY — nothing else lost) + appended postFixup libstdc++ `--prefix LD_LIBRARY_PATH` wrap (GLIBCXX fix; upstream v2.0.22 defines no postFixup, so the `(previousAttrs.postFixup or "")` compose is clean).

**Verdict: mechanism is OPTIMAL for 2.x — every alternative verified closed (as of 2026-10-05):**
- nixpkgs: locked 26.05 = 1.15.10, master = 1.18.34 — 1.x only (Obsidian Copilot ≥ 4.0.12 needs 2.0.3+).
- 2.x line ships NOTHING prebuilt: NO GitHub Releases (releases page = v1.18.x only, latest 1.18.34), NO npm 2.x (`opencode-ai@2.0.22` 404s, npm latest = 1.18.34), NO binary cache (upstream flake has no nixConfig substituters, no cachix). Only git tags — the ENTIRE 2.x line was v2.0.22 + v2.0.23.
- Rolling an own pkgs/ expression = owning ~100 lines of bun build logic against a fast-moving 2.x line — strictly worse drift exposure than upstream's maintained expression + 6-line override.
- Re-adding `follows` + overriding bun needs unstable nixpkgs anyway → no gain over the current free bun-1.4.2-from-upstream-pin.

**v2.0.23 (rev 0fd7e2829449b052abf0078666669302923d77af) fixes completions upstream** — switched to global `--completions` flag, output staged to real files first (comment: substitute rejects non-regular files). At/after the bump: DROP `postInstall = ":"` (completions return, one less drift patch), KEEP the libstdc++ wrap (binary-vs-nixpkgs linkage, tag-independent).

**Status:** user chose "Bump to v2.0.23" via AskUserQuestion; ExitPlanMode rejected with approval words → self-contained handoff brief delivered 2026-10-05 to the weaker executor (see [[plans-for-weaker-executor]]); NOT executed by me. Gates in the brief: lock rev = 0fd7e28…, direct package build (bun monorepo, 5–15 min = normal, 600s timeout), `--version` → 2.0.23, opencode.json byte-diff vs deployed, dry-build yoga AND latitude. Fallback = `git restore flake.nix home/opencode.nix flake.lock` (worktree-from-index; the staged index itself holds the known-good 2.0.22 state). Executor outcome UNKNOWN — verify via `git diff --cached --stat` (the obsidian-handler + litellm-secret staged changes must still be present, untouched).

**Revisit triggers** (switch mechanism when one opens): 2.x starts shipping GitHub release assets → tiny fetchurl+autoPatchelf derivation in pkgs/ (seconds to build, immune to upstream build drift, drops the input + second nixpkgs); npm `opencode-ai` hits 2.x → fetchurl from registry; nixpkgs picks up 2.x → plain `pkgs.opencode`; upstream adds a cache → local builds vanish. Efficiency note: yoga AND latitude each build the bun monorepo locally per bump — rebuilding latitude from yoga over Tailscale (`nixos-rebuild --target-host` / `nix copy --to ssh://latitude`) avoids the second build (offered, not applied).

Related: [[obsidian-litellm-integration-2026-10-04]], [[verify-versions-against-deployed-system]].
