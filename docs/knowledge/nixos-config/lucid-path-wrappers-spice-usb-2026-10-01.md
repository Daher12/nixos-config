---
name: lucid-path-wrappers-spice-usb-2026-10-01
description: iPhone USB passthrough EPERM root cause — lucidPath omitted
  /run/wrappers/bin, spice acl helper resolved unelevated; fix staged 2026-10-01
metadata:
  node_type: memory
  type: project
  originSessionId: sess_540e14cf-cec1-4e64-aa3b-e97c73db0fbc
---

iPhone→windows11 VM USB redirect broke ("Error setting USB device node ACL: Error setting facl: Operation not permitted", auto AND manual). Root cause: `home/lucid.nix` `lucidPath` (the pinned PATH for lucid.service, set during the DMS-removal caelestia-execDetached fix) omitted `/run/wrappers/bin`. Dock-launched virt-viewer therefore resolved `spice-client-glib-usb-acl-helper` via `$PATH` (nixpkgs patches spice-gtk to PATH-lookup it) to the plain store copy in `/run/current-system/sw/bin` — no `cap_fowner` → `acl_set_file` EPERM after polkit auth passed.

Chain of evidence: error string lives in the helper binary (not libvirt — 12.2.0 identical in previous gen, contains no "facl" message); polkit action `org.spice-space.lowlevelusbaccess` passed (error reached the facl step); NixOS wrapper at /run/wrappers/bin carries `cap_fowner,cap_setpcap=ep` (ambient-cap transfer via wrapper.c), mount is NOT nosuid; running virt-viewer pid env showed `PATH=/run/current-system/sw/bin:...` without wrappers. Worked "in the past" because pre-lucid sessions (DMS/uwsm) had full session PATH.

Fix STAGED 2026-10-01 (uncommitted, QC green: unit-env eval + dry-build yoga):
1. lucidPath now `/run/wrappers/bin:...` first (root fix — also covers fusermount/newuidmap/pkexec for ALL dock apps).
2. `SPICE_USB_ACL_BINARY=/run/wrappers/bin/spice-client-glib-usb-acl-helper` exported in the guest launcher script (modules/features/virtualization.nix) — upstream env override, immune to PATH games.

**Why:** privileged NixOS helpers exist only in /run/wrappers/bin; any launcher pinning a minimal PATH silently breaks them (store copies exist in sw/bin via systemPackages and shadow).

**How to apply:** needs switch + `systemctl --user restart lucid.service` (KillMode=process — dock apps survive), then relaunch viewer. Live no-rebuild workaround: from kitty `SPICE_USB_ACL_BINARY=/run/wrappers/bin/spice-client-glib-usb-acl-helper windows11`. Debug recipe: read dock-launched app env via `systemd-run --user --wait --pipe --collect /run/current-system/sw/bin/bash -c '...'` (sandbox can't read host /proc/PID/environ cross-namespace; my own shell PATH is rebuilt by /etc/profile — NEVER a valid sample of dock env). Helper protocol: stdin "busnum devnum\n" → polkit check of PARENT pid (skipped if uid==0) → ACL for getuid() → "SUCCESS". Open detail: who uaccess-ACLs iPhone nodes (helper was once observed succeeding partially — user:dk:rw- appeared on the node at plug time; node vanished mid-investigation when user unplugged).
