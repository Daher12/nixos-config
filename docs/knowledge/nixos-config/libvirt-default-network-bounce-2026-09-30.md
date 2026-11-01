---
name: libvirt-default-network-bounce-2026-09-30
description: Win11 VM fixes 2026-09-30 — network drift fix STAGED + timer/
systemd-merge added (QC green 2nd round), snapshot pre-virtio-video +
Downloads-pool removal EXECUTED; Part E (video QXL→virtio + memballoon,
approved) GATED on user guest-tools install D4 — exact sed block in file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_cde5542b-fbcc-4975-b4e3-6f5fc8ed958a
---

2026-09-30 session: user reported (a) normal win11 VM lost internet "since we changed something in our virtualization environment", (b) VM resolution "just blurry and big UI elements". Diagnosis → plan approved → user first asked for a lesser-executor handoff, then told the same session to proceed: ALL edits applied + staged, QC green.

**Internet root cause (journal-proven):** `modules/features/virtualization.nix` systemd.services.libvirt-default-network (~:303-334) compared `virsh net-dumpxml default` against the raw `pkgs.writeText` XML — dumpxml returns libvirt's CANONICAL form (injects `<uuid>` + bridge `<mac address='52:54:00:14:62:d0'/>`, reformats whitespace) so the compare NEVER matched → `net-destroy`+`net-undefine`+`net-define`+`net-start` at EVERY boot and every unit restart (nixpkgs bumps change the embedded `${pkgs.libvirt}` path → unit hash → mid-session restart): 32 destroys in `journalctl -u libvirt-default-network` since Sep 19 23:03. Drift-guard bug itself added 2026-06-15 (21c9bc1/876a59c) but was inert until the guests refactor (5f99a47, folded into baseline 240ad11) added the win11-work DHCP reservation = first real XML change. Failure modes: (1) VM running during destroy → tap unplugged, net-start does NOT re-attach → running VM with dead NIC; (2) failed `net-start` swallowed by `>/dev/null 2>&1 || true` + RemainAfterExit=true → never retried, net down until reboot. Live state at diagnosis: net active+autostart, only `windows11` domain (shut off, ran ~10:57 that day) — fresh start should DHCP fine.

**Fix APPLIED + STAGED 2026-09-30 (uncommitted, lucid-testing):** script rewritten — `norm()` strips `<uuid>`/`<mac …/>` and squeezes whitespace on BOTH sides before comparing; define-if-missing branch; on real drift with running domains (`virsh list --state-running --name`) → log + DEFER redefine (never unplug a running guest; residual normalization mismatches like attribute reorder become harmless defers); `net-start` errors NOT swallowed (visible failure, unit marked failed). Unit after/requires/wantedBy untouched. QC green: flake check exit 0, dry-build yoga (new unit-script-libvirt-default-network-start drv), `nix eval` of the script renders correctly (`tr -d ' \n\t'` inside the Nix `''` string keeps literal backslashes — intended, the shell interprets them).

**Post-switch verification (user, still pending):** `journalctl -u libvirt-default-network -b --no-pager | tail` must show NO destroyed/undefined lines; `virsh net-list --all` active+autostart. If guest still offline despite active net: `virsh net-dhcp-leases default` (lease for 192.168.122.139?) + `nft list ruleset | grep -E 'libvirt|122'` (NAT rules?) → that would be the libvirt firewall backend, a different bug.

**Resolution diagnosis (user action in virt-manager, NO repo change, still pending):** domain XML unchanged since 2026-06-15 — qxl ram/vram 65536, vgamem 16384, spice `gl=yes` (inert with QXL), spicevmc/vdagent channel, virtio NIC. QXL @16MB vgamem caps ~2560×1600 and CANNOT supply 3072×1920; yoga panel is 3072x1920@120 scale 2 → logical 1536×960 (3:2); launcher runs `virt-viewer --full-screen`. Sep 20 nixpkgs lock float (qemu 10.2.4, libvirt 12.2.0, dnsmasq 2.93; nothing pinned) most likely made the spice stack request physical size → guest falls back to a smaller mode stretched fullscreen = blurry + big UI. Fix: virt-manager, VM off → Video QXL→**Virtio** (+ viogpudo driver from /var/lib/libvirt/images/virtio-win.iso if Windows shows basic adapter, then reboot); fallback vgamem 16384→32768.

**Why:** the drift-guard bug is invisible in the module source (reads like a sane idempotency check) and bites intermittently guest-side (only when a VM survives a bounce); the resolution diagnosis lives nowhere in the repo (domain XML is user-managed state).

**How to apply:** if VMs "randomly lose networking" again, check `journalctl -u libvirt-default-network -b` for destroy/undefine triples FIRST — a REAL XML drift (guest added/removed) legitimately triggers one destroy on the next boot with no VMs running; that's by design. Never compare raw virsh XML output to authored XML without stripping uuid/mac. See [[win11-work-vm]], [[kitty-vs-ghostty-evaluation]] (same staged index).

**2026-09-30 follow-up (audit session):** full-picture audit approved further fixes, delivered as executor handoff ([[virtualization-audit-2026-09-30]]): the drift-DEFER branch now gets timer-retried (systemd.timers libvirt-default-network 15min/6h — requires REMOVING RemainAfterExit from the oneshot: a systemd timer cannot re-run an active RemainAfterExit unit); the QXL→virtio video flip moved from "user in virt-manager" into the approved handoff (gl must be enable='no' — virgl unsupported by Windows viogpudo; flip only AFTER guest tools install).

**EXECUTION RECORD (main session, same day, user said "execute"):** handoff Parts A–C done; D–E remain.
- Module (staged, QC green round 2): drift-fix script byte-identical through re-indent; all three `systemd.*` assignments MERGED into one `systemd = { tmpfiles…; services…; timers…; }` block — statix `repeated-keys` fails flake check at 3 separate `systemd.*` keys (2 passed before). Timer OnBootSec=15min/OnUnitInactiveSec=6h; RemainAfterExit removed. `filesystemType` → direct `config.features.filesystem.type`; `or [ ]` nit dropped. ⚠️ `rec` in guests mapAttrs is LOAD-BEARING (`desktop.exec = "${launcher}/bin/…"`) — an explorer's "dead rec" claim broke flake check once; keep it.
- Docs: REPO_OVERVIEW Known Gotchas entry (canonical-XML compare) + module row "self-healing default-network unit"; hosts/yoga/default.nix win11-work full creation runbook comment + snapshot-hint comment.
- Live (VM shut off): snapshot `pre-virtio-video` created (revert: `virsh snapshot-revert windows11 pre-virtio-video`); Downloads pool destroyed+undefined (dir untouched; only default+nvram pools left).
- QC validated the COMBINED staged index (incl. parallel-session kitty/matugen files): flake check 0, dry-build yoga 0 — both `unit-libvirt-default-network.service.drv` AND `.timer.drv` in closure.
- PENDING D1–D4 (user): D1 switch; D2 journal shows NO destroyed/undefined + net active; D3 VM boots with internet, dhcp-lease .139; D4 run `virtio-win-gt-x64.exe` from attached ISO in Windows (skip if Device Manager shows "Virtio GPU Driver"), reboot guest, shut down.
- PENDING Part E (approved; gate = D4 done + domstate shut off):
```
virsh -c qemu:///system domstate windows11        # must be shut off
virsh -c qemu:///system dumpxml windows11 > /tmp/windows11.xml
cp /tmp/windows11.xml /tmp/windows11.xml.bak
sed -i \
  -e "s|<model type='qxl'[^>]*/>|<model type='virtio' heads='1' primary='yes'/>|" \
  -e "s|<gl enable='yes'/>|<gl enable='no'/>|" \
  -e "s|<memballoon model='none'/>|<memballoon model='virtio'/>|" \
  /tmp/windows11.xml
grep -nE "type='virtio' heads|<gl |memballoon" /tmp/windows11.xml   # all 3 changed before defining
virsh -c qemu:///system define /tmp/windows11.xml
virsh -c qemu:///system dumpxml windows11 | grep -E "<video|model type=|<gl |memballoon"
```
Memory decision: memballoon virtio + KEEP 8 GiB (user choice). Never define a partial sed result; revert = define .bak or snapshot-revert. After E: boot → sharp native res, virt-viewer auto-resize via vdagent.

**2026-09-30 evening: post-switch verdict.** D2 CONFIRMED — drift fix deployed in gen 167 (15:27, boot 15:32) and WORKING: unit journal silent (zero output since Sep 28 22:33 vs 62 destroy-triples before), exit 0, timer fires 15min/6h without recreating the net (dnsmasq PIDs stable). D3 FAILED — VM internet still dead (run 15:35–15:37, "connected, no internet") → the bounce was a real bug but NOT the remaining cause; this file's own fallback prediction (libvirt firewall backend) was correct: `firewall_backend = "nftables"` auto-derived since 2026-09-13, see [[vm-nat-firewall-backend-2026-09-30]]. ⚠️ dnsmasq journal-DHCP-absence is NOT evidence: libvirt's dnsmasq logs zero DHCP transaction lines even during known-working windows. Evening execution (backend pin deployed gen 168 16:51, but D3 flipped to "unidentified network" → root cause #2 virbr0-untrusted input drop; net bounce executed by main session) all recorded in [[vm-nat-firewall-backend-2026-09-30]]. Part E + D4 still pending, unchanged.

**Late-evening close-out:** D4 (guest tools) DONE + Part E (sed flip, grep gate 3/3, define + dumpxml verified) EXECUTED the same evening; VM boots and works post-flip — details + open follow-ups (OpenSSH install, iTunes perf, windows mcp) in [[virtualization-audit-2026-09-30]]. This file's thread is COMPLETE.
