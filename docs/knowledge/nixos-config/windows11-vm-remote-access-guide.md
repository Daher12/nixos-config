---
name: windows11-vm-remote-access-guide
description: Reference — how to reach the windows11 VM from the host/another
  session SSH-first (bootstrap) then windows-mcp (SSE), incl. one-time pubkey
  setup and the exact start command for the MCP server
metadata:
  node_type: memory
  type: reference
  originSessionId: sess_a8dd1515-f643-4cf6-9a89-c000f05ca6eb
---

# Accessing the windows11 VM (SSH + MCP) — quick guide

Applies while VM has its DHCP reservation: **192.168.122.139**, user **linux-wm**. VM off = everything dead; VM boot via desktop launcher `windows11` (virt-viewer --full-screen) or `virsh -c qemu:///system start windows11`.

## Channel 1 — SSH (always available; sshd autostarts, survives reboots)

One-time setup (user pastes in an ADMIN PowerShell in the guest — admin-group keys must go to administrators_authorized_keys, NOT ~/.ssh; the icacls lockdown is mandatory, sshd rejects loose-ACL key files):

```powershell
Add-Content C:\ProgramData\ssh\administrators_authorized_keys 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF5RrQSrhkMR7+VRrpLRmkkKjnuP5n5KggU5RcJxyNmO zcode-win11-vm-mgmt'
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant "SYSTEM:F" "BUILTIN\Administrators:F"
```

Private key already on host: `~/.ssh/win11_vm_ed25519` (dedicated, no passphrase). Test:

```bash
ssh -i ~/.ssh/win11_vm_ed25519 -o StrictHostKeyChecking=accept-new linux-wm@192.168.122.139 "hostname"
```

Run PowerShell over it: `ssh -i ~/.ssh/win11_vm_ed25519 linux-wm@192.168.122.139 "powershell -Command \"<cmd>\""`.

## Channel 2 — windows-mcp (SSE, dies with the VM, must be started manually)

Check from host: `curl -s -N --max-time 5 http://192.168.122.139:8000/sse -H 'Accept: text/event-stream' | head -c 200` → `event: endpoint` = up.

Start it via SSH (if down):

```bash
ssh -i ~/.ssh/win11_vm_ed25519 linux-wm@192.168.122.139 "powershell -Command \"Start-Process -WindowStyle Hidden windows-mcp -ArgumentList 'serve','--transport','sse','--host','0.0.0.0','--port','8000','--allow-insecure-remote'\""
```

(if `windows-mcp` isn't on the SSH PATH, use its full path under `C:\Users\linux-wm\AppData\Local\Programs\Python\Python314\Scripts\`).

Client wiring already in place: ZCode user config `~/.zcode/cli/config.json` → `mcp.servers.windows-mcp` = `{"type":"sse","url":"http://192.168.122.139:8000/sse"}` (connects at session start; sessions started while the server was down see "Invalid request parameters" — restart server, restart session or use the raw SSE dance). opencode: repo toggle `custom.windowsMcp.enable` on yoga → same URL.

## Fallback — SSH tunnel (only needed if server ever runs guest-localhost-only / no --allow-insecure-remote)

`ssh -i ~/.ssh/win11_vm_ed25519 -N -L 8000:localhost:8000 linux-wm@192.168.122.139 &` then use `http://localhost:8000/sse`.

## Agent-level raw MCP (no native tools, no extra server) — the curl/SSE dance

GET /sse (keep open) → grab `session_id=` from `event: endpoint` → POST JSON-RPC (`initialize` → `notifications/initialized` → `tools/call` with `{"name":"PowerShell","arguments":{"command":...,"timeout":N}}`) to `/messages/?session_id=<id>` → responses arrive on the SSE stream as `data: {jsonrpc...}`. Quoting: write the PS command to a file, pass via `"$(cat file)"` — never inline `\"` escapes. Helper script was `/tmp/mcp-ps.py` (ephemeral; recipe above is the durable form). Related: [[windows11-vm-ssh-mcp-itunes-2026-09-30]], [[win11-vm-management-endpoint-2026-09-30]].
