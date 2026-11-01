---
name: win11-fresh-vm-plan-2026-10-02
description: Fresh Win11 VM from a new ISO — clone-XML-not-disk plan delivered
  2026-10-02 as ASSESSMENT (NOT executed); windows11 already has TPM2.0+secure
  boot; pending user decisions = ISO source + replace-vs-alongside
metadata:
  node_type: memory
  type: project
  originSessionId: sess_091a9e7e-321e-4148-8e2a-78064dfaab9e
---

User wants a NEW Windows 11 VM from a new ISO because the current Windows install "has some issues" (unspecified, 2026-10-02); asked whether the base virt-manager config can be copied. Delivered as assessment + plan — NOTHING executed yet.

**Live `windows11` facts (verified 2026-10-02, template for the new VM):**
- q35 `pc-q35-10.1`; UEFI secure boot: loader `/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd` `secure='yes'`, `<smm state='on'/>`, NVRAM `/var/lib/libvirt/qemu/nvram/windows11_VARS.fd` (template edk2-i386-vars.fd)
- TPM 2.0 emulated: `<tpm model='tpm-crb'><backend type='emulator' version='2.0'/>` (host swtpm enabled in modules/features/virtualization.nix)
- virtio disk + NIC; disk `/var/lib/libvirt/images/win11.qcow2` (cache=none, io=native, discard=unmap), 180G virtual / ~158G allocated; virtio-win ISO attached as CDROM (sda)
- 4 vCPU, 6 GiB RAM; MAC 52:54:00:03:b9:49 → DHCP .139; snapshot `pre-virtio-video`; pools default+nvram only; 698G free on cryptroot → space for a 2nd VM is a non-issue
- win11-work domain exists NOWHERE (qemu:///system and session both checked) — only its Nix launcher + .140 reservation

**Plan (clone the XML, not the disk):**
1. ISO into /var/lib/libvirt/images/ (user drops it or I fetch — language/edition + 24H2-vs-25H2 undecided)
2. `virsh dumpxml windows11 > new-vm.xml`; edit: new name, strip `<uuid>`, new MAC, new qcow2 path (`qemu-img create -f qcow2 … 180G`), drop runtime nvram path but KEEP the template attr (libvirt creates fresh VARS on define), attach installer ISO with `<boot order='1'/>` (remove order post-install)
3. Windows setup: load virtio storage driver from the already-attached virtio-win ISO; TPM/secure boot present → passes Win11 hard floor without registry hacks
4. Old VM kept as fallback (rename domain e.g. windows11-old), delete after the new install is proven
5. Nix side: REPLACE route = new VM takes the name `windows11` + MAC .139 + IP → launcher, SSH key, windows-mcp wiring all unchanged, ZERO Nix edits; ALONGSIDE route = add one `guests` entry (its DHCP reservation only applies via the drift unit when no guests are running — it defers by design)
6. Work enrollment (OOBE "Set up for work or school") belongs on the NEW VM; win11-work entry droppable — see [[win11-work-vm]]

**Pending user decisions:** who fetches the ISO (+ language/edition); replace vs alongside. Nothing was executed.
