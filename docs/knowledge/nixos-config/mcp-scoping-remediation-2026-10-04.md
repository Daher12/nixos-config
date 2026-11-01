---
name: mcp-scoping-remediation-2026-10-04
description: MCP audit + scoping fixes — dup nix MCP killed, mikrotik
  project-scoped (dead 1.10.0 paths fixed), windows-mcp workspace-scoped;
  staged, switch status unverified (2026-10-04)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5c20a383-7a2a-4876-8cb2-416318975842
---

MCP setup audit 2026-10-04, fixes EXECUTED same day. Verdicts: windows-mcp architecture correct (server ONLY in Win11 guest, Linux needs just the URL client entry); nix MCP belongs repo-scoped; mikrotik was INVERTED (user-global in ZCode everywhere, broken in RouterOS project — all 3 configs pinned GC'd `/nix/store/7zrd82…-mikromcp-1.10.0`).

Changes:
- `home/opencode.nix`: `pkgs.mikromcp` added to unconditional home.packages (toggle now = opencode entry only). STAGED uncommitted on top of 6488b6d (parallel session committed mid-flight; my change cleanly separate).
- `~/.zcode/cli/config.json`: user-global servers emptied (was nixos dup + mikrotik + windows-mcp).
- `/home/dk/nixos-config/.zcode/config.json`: mcp-nixos (kept) + windows-mcp SSE added — VM work happens from this repo.
- RouterOS `optimized_network` + `-program-wt` twin `.zcode/config.json` + `opencode.jsonc`: repointed to bare `mikromcp` (PATH). Fixes [[routeros-tooling-program]] project MCP.
- `~/.mikromcp/mikromcp-1.11.0` symlink removed (data files kept: routers.yaml, .env, identities.yaml, audit.ndjson, data/).

QC green: opencode.json byte-identical (sha d18a3670…), dry-build yoga OK (mikromcp-1.11.0 already in store, just links), all JSON valid, `nix eval` confirms mikromcp in home.packages.

**Why:** ZCode auto-connects ALL scopes (user+workspace) — global servers = tool-schema load + write-tool exposure in every session; hardcoded store paths rot on GC.

**How to apply:** User must `nixos-rebuild switch` BEFORE starting new RouterOS-project sessions (bare `mikromcp` not on PATH until switch). Then: this repo = nix MCP ×1 + windows-mcp (failed while VM off = expected); RouterOS dirs = mikrotik live; other dirs = no MCP. `4_5v_mcp`/`web_reader` are ZCode builtins, not config. mcp-nixos index can lag nixpkgs — use `channels` action for version truth ([[quickshell-packaging-eval-2026-09-30]]). Supersedes the "~/.zcode/cli/config.json windows-mcp" wiring note in [[win11-vm-management-endpoint-2026-09-30]].
