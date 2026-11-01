---
name: vm-nat-firewall-backend-2026-09-30
description: Win11 VM internet — TWO stacked root causes FIXED+VERIFIED 2026-09-30
  evening — (1) libvirt firewallBackend auto-flip to nftables since 2026-09-13,
  (2) virbr0 missing from firewall trustedInterfaces; both staged+deployed,
  user-confirmed working (internet+clicks, DHCP lease .139). Evidence traps +
  first-diagnostics inside
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a8dd1515-f643-4cf6-9a89-c000f05ca6eb
---

2026-09-30 evening follow-up to [[libvirt-default-network-bounce-2026-09-30]]: after the drift fix deployed clean (gen 167, built 15:27, boot 15:32), user reported VM internet STILL dead + new "can't click" mouse issue. VM ran only 15:35:13–15:37:39 today. Plan approved → handoff text → user "proceed" → EXECUTED in the same session (live debugging included).

**Root cause #1 (backend flip):** internet last worked BEFORE 2026-09-13. nixpkgs libvirtd module AUTO-DERIVES `virtualisation.libvirtd.firewallBackend`: default = `"nftables"` when `networking.nftables.enable = true`. Yoga enabled host nftables 2026-09-13 → silent backend flip (`cat /var/lib/libvirt/network.conf` → `firewall_backend = "nftables"` — FIRST diagnostic for any future VM-no-internet; readable as dk). Repo comment hosts/yoga/default.nix ("libvirtd operates through iptables-nft compat layer") was wrong from the day it was written. Sep-19 drift bounce was a parallel red herring for THIS symptom.

**Root cause #2 (virbr0 untrusted — found after switch #1 CHANGED the symptom):** switch #1 (gen 168, 16:51, backend pin live) turned "Connected, no internet" into "identifying → **Unidentified network**" = DHCP now dead too. Cause: nixos-fw nftables input chain policy drop trusts only lo/tailscale0; an ACCEPT in libvirt's own iptables/nft chains CANNOT override another table's drop (every base chain at a hook must accept). Fix: `networking.firewall.trustedInterfaces = [ "virbr0" ];` in modules/features/virtualization.nix — plain assignment is safe (listOf merges definitions; vpn.nix's `trustedInterfaces = lib.mkIf … [ "tailscale0" ]` coexists); verified `nix eval` → `["tailscale0","virbr0","lo"]`.

**Host nftables exonerated otherwise:** flushRuleset=false; nftables.service (NOTE: on 26.05 the firewall unit is `nftables.service`, there is NO nixos-firewall.service) only does table-scoped `delete table inet nixos-fw`, starts before dnsmasq at boot, zero mid-session reloads; ip_forward=1.

**iptables-availability fact (dead end avoided):** after the pin, `iptables` is ABSENT from /run/current-system/sw — that is NOT a blocker: pkgs.libvirt carries iptables-1.8.13 + nftables-1.1.6 in its closure (daemon wrapper PATH); net-start succeeded and would fail loudly if rules couldn't be applied. The nixpkgs module wires only `etc.ethertypes` from pkgs.iptables — no binary, no libvirtd.conf paths.

**Evidence traps:** (1) dnsmasq journal shows ZERO DHCPDISCOVER/ACK lines in the ENTIRE retained journal (since Sep 9) INCLUDING the known-working window — libvirt's dnsmasq does not log DHCP transactions; journal absence proves nothing. (2) /var/log/libvirt/qemu/windows11.log = 600 nobody:nogroup → root-only. (3) USB hostdev 0x14cd:0x1212 ABSENT from the host bus (only Intel 8087:0032 + hubs on yoga); startupPolicy=optional → inert, NOT the mouse cause. (4) /proc/<daemon-pid>/environ unreadable as dk.

**Mouse:** today = "live screen, clicks ignored" (2.5-min run possibly never reached interactive state — judge clicks only 2-3 min past the boot spinner); guest tools NEVER installed (user-confirmed) → no vdagent; video still qxl + `<gl enable='yes'/>`, memballoon none.

**EXECUTION RECORD (all staged, uncommitted; QC green twice — flake check 0, dry-build 0):**
- modules/features/virtualization.nix: `firewallBackend = "iptables";` inside the libvirtd block (comment explains the 2026-09-13 auto-flip) + `networking.firewall.trustedInterfaces = [ "virbr0" ];` (comment explains cross-table drop semantics).
- hosts/yoga/default.nix: stale coexistence comment corrected (now points to the pin).
- REPO_OVERVIEW.md: Known Gotchas "libvirt firewall backend auto-flips with nftables (fixed 2026-09-30)" + module-table row append.
- Live: `virsh net-destroy default && virsh net-start default` bounce EXECUTED by main session ~17:1x (VM off), dnsmasq new PID, net-start clean.
- User switch #1 done (gen 168 16:51, network.conf now "iptables"). Switch #2 (trustedInterfaces) DONE later that evening — internet + clicks user-confirmed, DHCP lease .139 live (headline facts in this file's description/index). UPDATE 2026-10-03: both fixes (firewallBackend="iptables" + trustedInterfaces=["virbr0"]) are now COMMITTED in modules/features/virtualization.nix (~lines 237/280) — tree clean @ a831c7b on lucid-testing, re-verified by [[config-audit-2026-10-03]].

**EMPIRICAL CONFIRMATION (user ran `sudo nft list ruleset | grep -iE 'libvirt|masquerade|virbr0'`, pre-switch #2):** iptables-nft tables live and CORRECT — `ip filter` INPUT jumps to LIBVIRT_INP (18k pkts traversed the jump = ordinary host traffic), LIBVIRT_INP holds `iifname "virbr0" udp/tcp dport 67 accept` (DHCP) + dport 53, LIBVIRT_FWI/FWO/FWX forward accepts, `ip nat` LIBVIRT_PRT MASQUERADE for 122.0/24→!122.0/24 — but EVERY virbr0-conditional rule counter is **0 packets**: DHCP from the guest never reached the accepts because `ip filter`'s ACCEPT cannot override `inet nixos-fw`'s input policy drop (cross-table semantics). Read: the bounce's ruleset is complete and merely waiting for the virbr0 trust. nft also prints "table ip filter/nat/… is managed by iptables-nft, do not touch!" warnings — expected, that IS the pinned backend. Post-switch-#2 verification: same grep should show virbr0 counters incrementing once the VM DHCPs.

**Pre-Part-E check:** `virsh domstate windows11` (must be shut off) + `virsh dumpxml windows11 | grep -E "<video|model type=|<gl |memballoon"`.

**Why:** both causes are invisible in repo greps (auto-derived default; firewall input policy) and stacked on each other — only the symptom CHANGE across switch #1 ("connected" → "unidentified") separated input-drop from NAT-backend.

**How to apply:** progress check: `nix eval … .config.networking.firewall.trustedInterfaces` + `.config.virtualisation.libvirtd.firewallBackend`, `cat /var/lib/libvirt/network.conf`, `virsh dumpxml windows11 | grep -E "<video|model type=|<gl |memballoon"`, `virsh domstate/snapshot-list windows11`. If DHCP lease OK but still no internet WITH correct LIBVIRT NAT rules present → genuinely different bug (tcpdump on virbr0); do NOT re-chase the drift unit (proven quiet since Sep 28 22:33). No net bounce needed after switch #2 (my bounce's rules persist; nftables reload only replaces nixos-fw).
