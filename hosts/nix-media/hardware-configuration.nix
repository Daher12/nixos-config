{ lib, modulesPath, ... }:

# Hardware Configuration - Intel N100 Mini PC
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
        "rtsx_usb_sdmmc"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/3944281c-cc0a-4585-a70c-08d6b6a41343";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/5E1D-18E0";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/mnt/disk1" = {
      device = "/dev/disk/by-uuid/84d38a22-73c0-4a30-8cf9-16241c435309";
      fsType = "xfs";
      options = [
        "noatime"
        "nofail"
      ];
    };

    "/mnt/disk2" = {
      device = "/dev/disk/by-uuid/5f49ed38-49da-4251-a0e6-fe92d52183d7";
      fsType = "xfs";
      options = [
        "noatime"
        "nofail"
      ];
    };

    # MergerFS Pool
    "/mnt/storage" = {
      device = "/mnt/disk1:/mnt/disk2";
      fsType = "fuse.mergerfs";
      options = [
        "x-systemd.requires=mnt-disk1.mount"
        "x-systemd.requires=mnt-disk2.mount"
        "x-systemd.after=mnt-disk1.mount"
        "x-systemd.after=mnt-disk2.mount"
        "fsname=storage"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=pfrd"
        "func.getattr=newest"
        "moveonenospc=true"
        "minfreespace=20G"
        "allow_other"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/a9b420e5-214f-48f8-bad5-516341eb288c"; }
  ];

  networking.interfaces.enp1s0.useDHCP = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
}
