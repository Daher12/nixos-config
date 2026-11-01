---
name: verify-versions-against-deployed-system
description: Package-version claims must be verified against the deployed
  system or the repo's own pins — MCP nix channel-index lookups can serve
  STALE versions (said quickshell 0.2.1 when deployed was 0.3.1)
metadata:
  node_type: memory
  type: feedback
  originSessionId: sess_edc95bc4-614e-4fcb-bbd0-9465f970e7ef
---

2026-09-30: asked "which quickshell do we run?", I answered from the mcp nixos `info` tool — it returned 0.2.1 for both stable and unstable. User corrected me with the real numbers (stable 0.3, unstable 0.3.1). Ground truth: `readlink -f /run/current-system/sw/bin/quickshell` → `…-quickshell-0.3.1`; corroborated by nix_versions history (0.3.0 in nixpkgs since 2026-08-27).

2026-10-04 repeats, both directions: (a) an Explore agent reported Brave 1.95.101; deployed was 1.96.59 (`readlink -f /etc/profiles/per-user/dk/bin/brave` — the store dir carries the version). (b) the MCP home-manager OPTION index said "no brave options" while the repo's HM release-26.05 actively uses `programs.brave` — the option index is as stale as the package index. Ground-truth move that day: `grep -a` policy-name extraction straight from the deployed ELF (`opt/brave.com/brave/brave`, NOT share/brave/).

**Why:** channel-index snapshots lag reality; a version "fact" built on one silently mis-sizes plans (the floor gate was about to pin a version we don't run) and costs a user correction round.

**How to apply:** for "what do we actually run" questions, read the deployed store path (`readlink -f /run/current-system/sw/bin/<pkg>` — the store dir name carries the version) or the repo's flake.lock pins / nixpkgs package expressions; treat MCP channel queries as a hint only and label them as such. When the user quotes concrete version numbers, assume they checked — re-verify mechanically before contradicting. Related: [[zcode-shell-sandbox-etc]], [[lucid-audit-quickshell-flake-2026-09-30]].
