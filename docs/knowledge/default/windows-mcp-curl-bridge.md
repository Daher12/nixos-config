---
name: windows-mcp-curl-bridge
description: Speaking the windows-mcp SSE protocol directly via curl when MCP
  tools aren't loaded in the ZCode session — verified session recipe, mcp.sh
  helper, tool inventory + App/Screenshot schemas, and its wedge pitfalls
metadata:
  node_type: memory
  type: reference
  originSessionId: sess_74283609-48d2-4976-b0cc-f4869fc62735
---

If a ZCode session starts while windows-mcp (192.168.122.139:8000, SSE transport) is down, its tools fail with "Invalid request parameters". You can drive it with plain curl: `GET http://192.168.122.139:8000/sse` yields `event: endpoint` + `data: /messages/?session_id=...`; POST JSON-RPC bodies to that endpoint (HTTP 202 = accepted); responses arrive as `event: message` lines on the SSE stream (~15 s ping keepalives).

Verified recipe (2026-10-01, server 4.0.10): helper script `/home/dk/.zcode/workspace/default/mcp.sh '<jsonrpc tools/call body with id 2>' [wait_s]` — opens `GET /sse` into a temp file (`curl -sN -m`), POSTs `initialize` (id 1) then `notifications/initialized` then your call (id 2) to `.../messages/?session_id=<sid>`, waits for the `data:` line containing `"id":2`, prints it. POST bodies must be exactly valid JSON — a stray `}}` comes back "Could not parse message", which looks like a session-state error but is just bad JSON.

- Tool inventory: App, Screenshot, Snapshot, Click, Type, Scroll, Move, Shortcut, Wait, WaitFor, Scrape, MultiSelect, MultiEdit, Clipboard, Process, Notification, Registry, PowerShell, FileSystem, DisplayInventory.
- App schema: `{mode: launch|launch_executable|resize|switch, name, executable, args (string or array), cwd, window_size, window_loc}`. `launch_executable` returns `{"pid":...}` and is the reliable GUI-app launcher (argv array, no quoting problems).
- Screenshot: zero args; returns a text block (cursor pos, desktop/window summary, plus "Screenshot Coordinate Scale" — the image is downscaled, multiply image coords by that factor before Click/Move) and a base64 PNG in `content[]` (decode+save with python3). Snapshot is the slower variant that also extracts the interactive UI tree/element ids.

Pitfalls learned the hard way:
- Every new SSE session must begin with `initialize` + `notifications/initialized` before any `tools/call`, otherwise every call returns "Invalid request parameters" — the error is about session state, not the arguments.
- The PowerShell tool does NOT enforce its timeout parameter: an infinite loop (e.g. a read loop where ReadFile returns TRUE with 0 bytes at EOF) hangs the call forever and the server's serialized queue wedges behind it, silencing other tools too.
- Recovery: kill the wedged powershell worker PID via the Process tool (separate code path), or restart the whole server via SSH. Keep commands short and bounded; heavy enumerations (Get-NetFirewallRule over all rules, Win32_ReliabilityRecords) wedge it for minutes.
- Desktop visibility depends on where the server was started: SSH-started → UI tools see the wrong desktop ("WinDisc"); started manually by the logged-in user in the console session → UI tools see the real desktop and `App.launch_executable` lands GUI apps in session 1 (verified 2026-10-01 by launching iTunes on the console desktop and screenshotting it). Prefer SSH + `-EncodedCommand` for any heavy logic; use the bridge for UI actions only.

Related: [[win11-vm-access]], [[win11-vm-troubleshooting]].
