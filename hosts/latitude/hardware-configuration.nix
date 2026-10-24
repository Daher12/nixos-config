# Hardware detection data (nixos-generate-config). The disk layout itself is
# declarative in ./disks.nix (disko generates fileSystems, the LUKS entry and
# swapDevices from it) — do not re-add manual fileSystems/luks here.
{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "sd_mod"
      "sdhci_pci"
    ];
    # kvm-intel + empty generate-config leftovers removed 2026-10-24:
    # features.virtualization is off on this host, nothing uses /dev/kvm.
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # cpu.intel.updateMicrocode comes from modules/hardware/default.nix
  # (isPhysical branch, mkDefault true).
}
