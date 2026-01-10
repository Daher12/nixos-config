{ config, lib, pkgs, modulesPath, ... }:

# Hardware Configuration - Intel N100 Mini PC
#
# Storage layout:
#   /           - NVMe (ext4) - OS and Docker configs
#   /boot       - EFI System Partition
#   /mnt/disk1  - HDD 1 (XFS)
#   /mnt/disk2  - HDD 2 (XFS)  
#   /mnt/storage - MergerFS pool combining disk1+disk2
#
# MergerFS provides JBOD-style pooling without RAID overhead.
# Files are distributed across disks; no redundancy.

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Kernel modules
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "sdhci_pci" "rtsx_usb_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];  # Virtualization support
  boot.extraModulePackages = [ ];

  # Root and boot filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3944281c-cc0a-4585-a70c-08d6b6a41343";
    fsType = "ext4";
  };
  
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5E1D-18E0";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Storage pool: individual XFS disks
  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-uuid/84d38a22-73c0-4a30-8cf9-16241c435309";
    fsType = "xfs";
    options = [ "noatime" "nofail" ];  # noatime reduces writes, nofail prevents boot failure
  };
  
  fileSystems."/mnt/disk2" = {
    device = "/dev/disk/by-uuid/5f49ed38-49da-4251-a0e6-fe92d52183d7";
    fsType = "xfs";
    options = [ "noatime" "nofail" ];
  };
  
  # MergerFS union mount - combines disks into single namespace
  fileSystems."/mnt/storage" = {
    device = "/mnt/disk1:/mnt/disk2";
    fsType = "fuse.mergerfs";
    options = [
      # Systemd ordering: wait for underlying disks before mounting
      "x-systemd.requires=mnt-disk1.mount"
      "x-systemd.requires=mnt-disk2.mount"
      "x-systemd.after=mnt-disk1.mount"
      "x-systemd.after=mnt-disk2.mount"
      
      # FIX: Added fsname for better identification in df/monitoring
      "fsname=storage"
      
      # Caching
      "cache.files=partial"       # Cache file handles for better read performance
      "dropcacheonclose=true"     # Free cache when files close (good for large media)
      
      # File placement
      "category.create=pfrd"      # Path-preserving with fallback to random disk
      "func.getattr=newest"       # Return newest file attributes on conflicts
      
      # Space management
      "moveonenospc=true"         # Auto-move files if disk fills up
      "minfreespace=20G"          # Keep 20GB free before switching disks
      
      # Access
      "allow_other"               # Allow non-root users (required for containers)
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/a9b420e5-214f-48f8-bad5-516341eb288c"; }
  ];

  # Network
  networking.interfaces.enp1s0.useDHCP = true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;  # Security patches
}

