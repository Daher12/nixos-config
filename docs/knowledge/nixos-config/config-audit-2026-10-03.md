---
name: config-audit-2026-10-03
description: Read-only audit of modules/core + modules/features + hosts/yoga
  (2026-10-03) — verdict "nothing broken live"; 4 real findings + 2 security
  tradeoffs + minors; fixes OFFERED, NOT applied
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7f4b3836-44dc-45f7-a1c2-b24995842500
---

2026-10-03, user asked "any issues with my current nix config (core + feature modules + yoga host)" under plan mode → delivered as ASSESSMENT text (no ExitPlanMode, no edits — the [[plans-for-weaker-executor]] pattern). Scope: all 37 .nix files (~3,900 lines) — modules/core (12), modules/features (20), hosts/yoga (5) — plus flake.nix, profiles/{laptop,desktop-hyprland,desktop-gnome}.nix, lib/mkHost.nix, and modules/hardware (ryzen-tdp, amd-gpu). Branch lucid-testing @ a831c7b, tree clean.

**Verdict:** nothing broken in what yoga deploys. Verified sound: impermanence rollback ordering (incl. hibernate-resume guard + blank-template assertions), sops ssh-identity ↔ persisted host-key files, zram-100% + oomd swap-kill + 16G disk swapfile coherence, yoga-s2h internally consistent with HIBERNATE_ENABLED=0 ([[yoga-hibernate-status]]), fstrim auto-detection correct with disko's discard=async (fstrim off), and the trustedInterfaces merge (vpn.nix tailscale0 + virtualization.nix virbr0, lists concatenate) — that libvirt NAT fix pair is now COMMITTED, closing the STAGED state recorded in [[vm-nat-firewall-backend-2026-09-30]].

**Real findings (fixes offered at end of session; user had NOT chosen yet):**
1. **ADB half-wired** — hosts/yoga/default.nix:31 (`extraGroups = [ "adbusers" ]`) + :342 (`pkgs.android-tools`), but `users.groups.adbusers` is defined nowhere (grep-verified) and no android udev rules via `services.udev.packages` anywhere. NixOS silently drops membership in an undefined group → USB adb/fastboot as dk still fails; the two lines are dead weight. Fix: define the group + install udev rules; nixpkgs has NO `android-udev-rules` package (MCP search verified) — first check whether the android-tools store path ships `lib/udev/rules.d/*`.
2. **NAS automount guard partly hollow** — core/networking.nix:43 strips NetworkManager-wait-online from network-online.target (`wantedBy = mkForce []`, deliberate boot-speed default), but nas.nix:49–52 orders the NFS automount on `network-online.target`, which then has no online semantics on an NM host. Only real guard = requires/after tailscaled.service (active ≠ connected). Early-boot access to /mnt/nas can hit the soft-mount timeout; low impact (automount + soft + timeo=600 contain it).
3. **core_pattern → nonexistent binary** — core/sysctl.nix:37 `"|/bin/false"`; NixOS /bin holds only `sh`, so the kernel exec fails and logs a core-dump-helper-failed line per crash. Net effect identical to intent (cores discarded), mechanism wrong; suggested `/run/current-system/sw/bin/false`.
4. **users.nix passwordless footgun** — core/users.nix:51–57: `mutableUsers = false` unconditional, `hashedPasswordFile` only `mkIf sopsEnabled` → a sops-off host gets a silently unloginable user. Yoga unaffected; suggested an assertion to make it fail loudly.

**Security tradeoffs re-flagged for re-confirm (deliberate-looking):** sudo `Defaults !tty_tickets` + `timestamp_timeout=30` (one successful sudo unlocks all terminals for 30 min); virbr0 blanket-trusted (virtualization.nix:280) — guests reach every host service, tighter alt = extraInputRules accepting only UDP 67/53 on `iif "virbr0"`.

**Minor:** bare non-mkDefault assignments that hosts can't override without mkForce — vpn.nix:40 `checkReversePath`, profiles/laptop.nix:38–42 logind lid settings; mnamer.nix apiKeys options write plaintext keys into the world-readable store (/etc/mnamer/config.json in the closure, no sops path — unused on yoga, trap); features.kernel enabled-by-default (`mkEnableOption // { default = true; }`); `boot.tmp.cleanOnBoot` redundant with useTmpfs.

Offered follow-up: findings 1/3/4 are one-liners; the NAS guard (2) needs a small design decision first.
