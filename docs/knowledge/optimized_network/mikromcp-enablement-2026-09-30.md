---
name: mikromcp-enablement-2026-09-30
description: How to bring the MikroTik MCP back up (verified 2026-09-30) —
  registered nowhere, old 1.10.0 store binary GC'd, NixOS toggle OFF on
  lucid-testing; build mikromcp 1.11.0 via nix-build from nixos-config/pkgs and
  register in ~/.zcode/cli/config.json or opencode.jsonc; ~/.mikromcp/.env is
  self-loaded; audit.ndjson = evidence trail
metadata:
  node_type: memory
  type: project
  originSessionId: sess_c9f33870-4aae-40f2-b097-a1d60d07d2b5
---

Investigated 2026-09-30 (that ZCode session had NO MikroTik MCP tools — enabling is Step 0 before any device work):

**✅ COMPLETED 2026-10-04 (execution session): build + smoke test + registration DONE.** `nix-build` succeeded → `/nix/store/5r7v5z9xi0iafny4c25inrvrl2vb51qg-mikromcp-1.11.0`, GC-shield symlink `~/.mikromcp/mikromcp-1.11.0`. Stdio smoke test (initialize + tools/list, ZERO device calls): serverInfo `mikromcp 1.11.0`, identities count 0 (superadmin-builtin), **123 tools** incl. all six key tools (`list_interfaces`, `list_dhcp_leases`, `run_command`, `manage_script`, `run_script`, `manage_dhcp_lease`) **plus `get_log`** (use for Phase A log reads). **Final wiring (what actually attached):** the OPERATOR installed `mikromcp` into the NixOS user profile (`/etc/profiles/per-user/dk/bin/mikromcp`, PATH-resolving, GC-safe) and switched the repo's tracked workspace configs (`.zcode/config.json` server `mikrotikmcp` + main-repo `opencode.jsonc` server `mikrotik`) to bare `mikromcp` — those two files are MODIFIED-uncommitted on main; tools attach as `mcp__mikrotikmcp__*` (workspace name wins). My `mikrotik` entry in `~/.zcode/cli/config.json` (pointing at the nix-build symlink) stayed as a redundant fallback outside this workspace. Phase A ran live through this stack 2026-10-04 02:05–02:25 — verified working incl. `run_command` within cmdAllow (`/interface/wifi/steering/print` passed). NixOS declarative lane untouched (toggle still false on lucid-testing). **Re-verified 2026-10-05 (read-only): `list_routers` shows all 4 routers (hap-ax2 default, hap-ax2-cap .239, hap-ac-cap .235, hex-poe .237, all https/443, rosVersion 7.23.5) and `check_router_health` healthy on all four.**

- **Down everywhere:** `~/.zcode/cli/config.json` mcp.servers has only `nixos`; `~/.config/opencode/opencode.json` only `nixos`; project `.opencode/` has no opencode.json. The program worktree `opencode.jsonc` entry hardcodes `/nix/store/7zrd82znikxw1yjhdcf3nw96bkbcd7ix-mikromcp-1.10.0/bin/mikromcp serve` — that store path is **garbage-collected, dead; never reuse**.
- **NixOS owns the declarative registration and it is OFF:** `/home/dk/nixos-config` (branch **`lucid-testing`**) — `home/opencode.nix` registers `mikrotik` = `${lib.getExe pkgs.mikromcp} serve` only when `custom.mikrotikMcp.enable = true`; the toggle sits at `hosts/yoga/default.nix:21` = **false**. Flipping it means a system switch through the operator's update-safe flow — an executor must not switch the NixOS system unasked.
- **Build (1.11.0):** `nix-build -E 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dk/nixos-config/pkgs/mikromcp.nix {}' -o /home/dk/.mikromcp/mikromcp-1.11.0` (host has no node/npm on PATH; the `-o` symlink doubles as GC shield; `~/.mikromcp` is impermanence-persisted). Package = npm `mikromcp` (github.com/AliKarami/MikroMCP); 1.11.0 adds per-router SSH-key auth + fixes command injection in ping/traceroute/torch; **changelogs list NO fix for the manage_dhcp_lease make-static defect** (HTTP 400 `unknown parameter dynamic`, hit on 1.10.0 at 2026-09-13T22:06:58Z, correlationId `2dG5B-mNVtBLbOCbhVMZJ`).
- **Register session-locally (no system change):** ZCode → add to `~/.zcode/cli/config.json` mcp.servers: `"mikrotik": {"command": "/home/dk/.mikromcp/mikromcp-1.11.0/bin/mikromcp", "args": ["serve"], "type": "stdio"}` (tools then appear as `mcp__mikrotik__*`; OpenCode names them `mikrotik_*`). Restart the session after editing.
- **Server state intact at `~/.mikromcp/`:** `routers.yaml` (hap-ax2 .1, hap-ax2-cap .239, hap-ac-cap .235, hex-poe .237; all https/443, rejectUnauthorized=false, rosVersion 7.23.5, creds via env); `.env` (mode 600 — MIKROMCP_TRANSPORT=stdio, CONFIG_PATH, DEFAULT_ROUTER=hap-ax2, AUDIT_LOG_PATH, ROUTER_*_USER/PASS for mcp-svc, CONFIRMATION_SECRET) — the server **self-loads** this .env (proven: the old OpenCode registration passed no env and worked); `identities.yaml` empty → sessions run as superadmin-builtin. **Never print/commit the .env.**
- **`~/.mikromcp/audit.ndjson` = append-only per-call audit trail** (attempt/success/failure + correlationId + params); `data/write-journal.ndjson` holds write snapshots. Cite correlationIds in evidence files.
- **cmdAllow scope: `["/user*", "/interface wifi*"]`** (operator-granted 2026-08-28) — `/ip dhcp-server lease` etc. is denied by design → dedicated tools or the single-command script workaround; on denial STOP; never widen.

Related: [[mikrotik-mcp-diagnostic-techniques]], [[open-changesets-portfolio-audit]], [[tooling-program-2026-09-13-branches]].
