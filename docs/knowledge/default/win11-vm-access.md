---
name: win11-vm-access
description: How to access the windows11 VM — SSH admin key setup completed
  2026-10-01, windows-mcp location and restart procedure
metadata:
  node_type: memory
  type: project
  originSessionId: sess_74283609-48d2-4976-b0cc-f4869fc62735
---

The windows11 VM (libvirt guest `windows11`, hostname DESKTOP-TDTHSIQ, IP 192.168.122.139) is reachable two ways:

- **SSH (reliable, admin)**: `ssh -i ~/.ssh/win11_vm_ed25519 linux-wm@192.168.122.139`. The guide's one-time setup was completed 2026-10-01 (pubkey in `C:\ProgramData\ssh\administrators_authorized_keys` with icacls lockdown, sshd restarted) — passwordless admin auth verified. SSH sessions are elevated (full admin token). Run PowerShell via `-EncodedCommand` (UTF-16LE base64) to avoid quoting hell. Best pattern for read-only sweeps: write the script to a local file, then `timeout 120 ssh ... powershell -NoProfile -EncodedCommand "$(iconv -f UTF-8 -t UTF-16LE script.ps1 | base64 -w0)"` — the host-side `timeout` is the only reliable bound, so prefer SSH over windows-mcp's PowerShell tool for anything non-trivial (that tool wedges on long commands); stderr may carry CLIXML progress noise, ignore it. For bounded installs/uninstalls with real exit codes, start msiexec via `[System.Diagnostics.Process]::Start($psi)` + `$p.WaitForExit(600000)` — `Start-Process -PassThru` without `-Wait` leaves ExitCode null, and `Wait-Process -Timeout` only raises a non-terminating error on expiry.
- **windows-mcp**: pip package (windows-mcp 0.8.7 / server 4.0.10), NOT on PATH in non-interactive SSH sessions — full path `C:\Users\linux-wm\AppData\Local\Programs\Python\Python314\Scripts\windows-mcp.exe` (runs as python.exe). Restart procedure: find PID via `netstat -ano | findstr :8000`, `taskkill /PID <pid> /F`, then from SSH `start /b "" <full path> serve --transport sse --host 0.0.0.0 --port 8000 --allow-insecure-remote` (`Start-Process` died silently; `start /b` works). A server started via SSH lives in the SSH session: PowerShell/Process/FileSystem/Registry tools work, but UI tools (Snapshot) see the wrong desktop ("WinDisc" instead of the console). Conversely, a server started manually by the logged-in user in the console session (done 2026-10-01) sees the real desktop, and its App tool's `launch_executable` lands GUI apps in session 1 — the reliable way to do console-session launches (the `schtasks /create /it` + `/run` trick failed to spawn iTunes that same evening); drive it with the curl-bridge helper below.

See [[windows-mcp-curl-bridge]] for driving it without ZCode MCP integration and [[win11-vm-troubleshooting]] for open issues.
