---
name: routeros-tooling-program
description: RouterOS hardening/tooling program plan (explained 2026-09-13, not
  executed) for ~/Dokumente/RouterOS/optimized_network — verdicts, network
  context, and my assessment caveats
metadata:
  node_type: memory
  type: project
  originSessionId: sess_18e8cae6-ec25-44b5-a52c-5eb3076b19ba
---

On 2026-09-13 the user asked for an *explanation only* (not execution) of an evaluated program plan: "NixOS Config, Repo Tooling, Minimal RouterOS Hardening", targeting a second repo at `/home/dk/Dokumente/RouterOS/optimized_network` (own AGENTS.md, changesets/templates/evidence structure, ~8 GB `core.*` dumps, cleartext admin passwords in overview/network-overview-2026-08-21.md ~lines 113–119).

Network context from the plan: MikroTik hap-ax2 192.168.88.1, hap-ax2-cap .239, hap-ac-cap .235, hex-poe .237 (QCA8337 switch chip), FRITZ!Box .244 (intentionally dynamic DHCP), management LAN 192.168.88.0/24, 13 dynamic leases, `mikrotik_*` MCP tools (mikromcp), SSH-key router access since 2026-09-10.

Plan verdicts: ADOPTED config-first = disko/impermanence/sops-nix/nixosTests (rebuild-only), host firewall (SSH only from 192.168.88.0/24), LiteLLM on 127.0.0.1:4001, gen-context.sh role bundles + light-model prompt cards, host-side router `/export` backups via SSH + weekly user timer, C024 static-lease changeset DRAFT-only (separate reviewed session). REJECTED: bridge horizon / bridge filters / DHCP snooping — QCA8337 forwards in hardware, CPU filters blind or disable offload (benchmark 542→146 kpps), CAPs bridge main SSID locally. DEFERRED: ARP reply-only until after C024.

My assessment caveats surfaced to the user: (1) ordering flaw — Step 1 baseline git commit precedes Step 2 password redaction, so plaintext lands in git history; redact before baseline. (2) The plan's A0 auto-detect will find `/home/dk/nixos-config` (this repo), making it the target; its A2 sops skeleton and A5 impermanence module would duplicate existing setup here. (3) Plan's generic "workstation" host needs mapping to a real host (likely yoga); SSH allowlist to 192.168.88.0/24 assumes a static management LAN.

Status: explained only; user has not requested execution. Binding constraint of the plan: zero RouterOS writes (T0 read-only MCP calls only). See [[repo-audit-2026-09-09]] for the sops admin-key staleness that intersects with the plan's secrets work.
