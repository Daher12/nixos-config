---
name: win11-vm-management-endpoint-2026-09-30
description: windows11 VM remote management setup — OpenSSH WORKING (port 22
  host-reachable), windows-mcp (guest, SSE :8000) unreachable because uvicorn
  bound guest-localhost AND CLI refuses --host 0.0.0.0 without auth; user
  choosing --auth-key vs --allow-insecure-remote; client wiring pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a8dd1515-f643-4cf6-9a89-c000f05ca6eb
---

2026-09-30 late evening, user is building remote management for the windows11 VM (192.168.122.139, DHCP-reserved):

- **OpenSSH Server: WORKING.** Port 22 open and reachable from the host (verified via `/dev/tcp/192.168.122.139/22`).
- **windows-mcp: NOT reachable from host.** Runs in the guest as SSE on port 8000 (uvicorn log "running on http://localhost:8000" = bound 127.0.0.1 inside the guest). Host probe: port 8000 closed. User already added the Windows firewall rule for 8000 scoped to `192.168.122.0/24`.
- **Auth blocker:** `windows-mcp serve --transport sse --host 0.0.0.0 --port 8000` refuses to start: "Refusing to bind HTTP transport to '0.0.0.0' without authentication. Use --auth-key <token> or --oauth-client-id/--oauth-client-secret. Or pass --allow-insecure-remote". Options presented:
  - (A, recommended) generate token in PowerShell, start with `--auth-key`, clients send `Authorization: Bearer <key>`; URL stays `http://192.168.122.139:8000/sse`.
  - (B) `--allow-insecure-remote` — acceptable here because the VM's only network is the host-local NAT bridge (nothing on LAN/internet can initiate to 192.168.122.0/24); residual risk = any process on the host or in the VM could drive the MCP.
- **RESOLVED same evening:** user chose (B) `--allow-insecure-remote`; server restarted on 0.0.0.0:8000; SSE handshake verified from the host (`curl -N http://192.168.122.139:8000/sse` returns `event: endpoint` + session id). Wiring DONE both clients — repo opencode (`custom.windowsMcp.enable` toggle, enabled on yoga, STAGED uncommitted) and ZCode user scope (`~/.zcode/cli/config.json` mcp.servers) — details + gotchas in [[windows11-vm-ssh-mcp-itunes-2026-09-30]]. HTTP 404 on `/` is normal (no landing page).

**Why:** setup paused mid-flow on the auth decision; the host-only-bridge reachability argument is the load-bearing justification if insecure mode is chosen.

**How to apply:** on resume, retest `http://192.168.122.139:8000/sse` from the host first, then wire the client(s). Related: [[vm-nat-firewall-backend-2026-09-30]] (network fix that made the bridge usable), [[virtualization-audit-2026-09-30]].

**Update 2026-10-06:** opencode startup error with VM off fixed — entry in `home/opencode.nix` now ships `enabled = false` (v2.0.23 has NO conditional loading: old command-form `enabled` gone, booleans only; verified in source, `mcp.enabled` migrates to native `disabled`). Behavior: no connect attempt at startup (no banner while VM off); with VM+server up connect manually via `/mcp` → select → Enter (verified in v2.0.23 source: initial load skips disabled, but the dialog's connect path does NOT re-check the flag). STAGED uncommitted; live after next switch. Host carries zero windows-mcp software — VM install is sufficient, the opencode entry is just a URL pointer.
