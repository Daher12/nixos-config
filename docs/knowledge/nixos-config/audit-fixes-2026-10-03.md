---
name: audit-fixes-2026-10-03
description: 2026-10-03 audit fixes staged on lucid-testing — virbr0 scoped
  firewall + new VM test, ADB wiring, NAS tailscale-online guard, users.nix
  assertion, sudo per-tty; user must switch + live-verify
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7f4b3836-44dc-45f7-a1c2-b24995842500
---

Full config audit (core + features + yoga) 2026-10-03 → fixes EXECUTED, staged uncommitted on lucid-testing (12 files, 289+/33−), QC green (flake check + dry-builds yoga/yoga-gnome/latitude/nix-media + NEW VM test). User must `nixos-rebuild switch --flake .#yoga` then live-verify; nothing committed.

**virbr0 hardening**: virtualization.nix blanket `trustedInterfaces=["virbr0"]` → scoped `extraInputRules` (udp 67, udp+tcp 53, iifname "virbr0") — Windows guest now reaches ONLY DHCP/DNS on host. ExtraInputRules is nftables-only (no-op under iptables backend where libvirt rules coexist anyway). Pinned by NEW `tests/virbr0-firewall.nix` (`nix build .#nixosTests.x86_64-linux.virbr0-firewall`, PASSED 169.9s): real module imported, libvirtd mkForce-off in test node (needs users.users.qemu-libvirtd isSystemUser/group stub or NixOS user assertions fail), networkd bridge virbr0 + services.dnsmasq stand-in, client VM proves DHCP lease + UDP/TCP DNS pass and canary :8080 is dropped. Gotchas hit: `wait_for_unit` on transient python http.server returns before listen → use `wait_for_open_port`; `nix eval --json`+`--raw` are mutually exclusive; dotted sysctl keys need quoting (`sysctl.'"kernel.core_pattern"'`).

**Other fixes**: yoga ADB half-wiring → `users.groups.adbusers = {}` + generic udev rule (ID_USB_INTERFACES *ff4201* = Android debug interface, vendor-list-free, +uaccess; android-tools ships NO udev rules, verified 35.0.2 store path; udevadm verify passes modulo sandbox group lookup; live test = plug phone + `adb devices`). nas.nix hollow network-online dep (NM-wait-online disabled in core/networking) → oneshot `tailscale-online.service` (tailscale status --json BackendState=Running, 30s loop, requires tailscaled) pulled by x-systemd.requires at first /mnt/nas access. core_pattern → `|${pkgs.coreutils}/bin/false` (NixOS has no /bin/false). users.nix assertion: no-sops + no-password = eval error (all 3 hosts use sops, unaffected). sudo `!tty_tickets` DROPPED (per-tty tickets restored, timeout option kept). kernel.nix enable now default-false + laptop profile sets it mkDefault true (yoga zen 7.2.8 unchanged, nix-media 6.18 host-pin unchanged). vpn checkReversePath + laptop logind lid settings → mkDefault. boot.nix cleanOnBoot dropped (redundant w/ tmpfs).

**statix lesson**: repeated-key warning fires at ≥3 assignments of one top-level key in a module (HEAD clean with 2, my 3rd users/services block failed the gate) — merge into one block; yoga udev rule lives inside the journald `services = { }` block for that reason.

**Why:** [[vm-nat-firewall-backend-2026-09-30]]'s trustedInterfaces half is now superseded by the scoped rules (REPO_OVERVIEW § "virbr0 guest→host traffic" documents it).

**How to apply:** SWITCHED + LIVE-VERIFIED 2026-10-03 ~02:25: `nft list ruleset` shows the 3 commented nixos-fw rules; windows11 running with DHCP lease .139 (hostname windows11, MAC matches reservation); libvirt's own iptables-nft virbr0 chains carry live DNS counters (211 pkts). Two-layer ruleset is EXPECTED: libvirt ip filter chains AND inet nixos-fw both evaluate — our scoped rules are what lets DHCP/DNS survive nixos-fw's policy drop. Optional last check (not yet done): from guest, host 192.168.122.1:22 etc. must fail. Commit still pending (user).
