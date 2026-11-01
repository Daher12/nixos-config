---
name: nix-media-tailscale-ssh-access
description: ssh nix-media works via Tailscale SSH (MagicDNS + tailscaled :22
  intercept, no ssh-config alias) — each attempt needs a browser check URL;
  foreground ssh stalls SILENTLY, background it and hand the URL to the user
metadata:
  node_type: memory
  type: reference
  originSessionId: sess_22722a8a-e610-464e-b9f9-e46386d45533
---

Agent-side SSH to nix-media (discovered 2026-10-04): **`ssh nix-media` works via Tailscale SSH**. There is NO active `Host nix-media` entry in `~/.ssh/config` (only a commented-out skeleton) — the MagicDNS name resolves to 100.123.189.29 and tailscaled intercepts port 22; the host's regular sshd is never involved. Plain `ssh dk@100.123.189.29` hits the same intercept.

**Browser-check flow**: the tailnet ACL runs SSH in "check" mode. Every new session attempt prints:
```
# Tailscale SSH requires an additional check.
# To authenticate, visit: https://login.tailscale.com/a/<code>
```
and then waits INDEFINITELY. The URL is per-attempt — a fresh ssh gets a fresh URL, the old one dies with the attempt.

**Silent-stall trap**: a foreground/BatchMode ssh to a tailscale IP that shows no output and never times out is almost certainly parked in this check (burned 2026-10-04: killed a "hung" session that was just waiting; its output log was even empty because the URL hadn't flushed).

**Working recipe (2026-10-04)**:
1. Launch as a background task: `timeout 280 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new nix-media '<cmds>'` (BatchMode is fine — Tailscale SSH authenticates via tailnet identity, not client keys).
2. `sleep 5`, read the task's stdout log → the fresh auth URL.
3. Hand the URL to the user (one click, they're logged in to Tailscale already). The background session then proceeds and streams the command output.
4. If the timeout expires before the click, relaunch — new attempt, new URL.

Note: earlier failures "Host key verification failed" were just BatchMode refusing the unknown host key; `accept-new` fixes that and is safe on the tailnet-internal address.

**2026-10-19 wrinkle**: BatchMode+timeout did NOT save it this time — all attempts (ssh/tailscale ssh, BatchMode, timeout) parked forever on fresh browser-check URLs (tailnet "check" mode for user→tagged-device SSH, nix-media is a tagged device). Workaround path discovered: the host's **real sshd listens on port 26** (`sshPort = 26` in hosts/nix-media/default.nix) and TCP works, but auth needs a key in `~dk/.ssh/authorized_keys` — which the repo does NOT manage anywhere (no authorized_keys in any module; trust is imperative), and yoga's `~/.ssh/id_ed25519` is not authorized there. Declarative keys were approved in [[repo-review-2026-10-19]] — once landed, `ssh -p 26 nix-media` becomes the agent path.

First use case: read-only litellm diagnostics on nix-media ([[obsidian-litellm-integration-2026-10-04]]). Related: [[zcode-shell-sandbox-etc]].
