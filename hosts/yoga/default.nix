# hosts/yoga/default.nix
{ config, pkgs, inputs, lib, ... }:

let
  btrfsOpts = lib.mkAfter [ 
    "compress-force=zstd:1" 
    "noatime" 
    "nodiratime" 
    "discard=async" 
    "space_cache=v2" 
  ];
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
    ./hardware-configuration.nix
    ./modules/ryzen-tdp.nix
    
    ../../profiles/laptop.nix
    ../../profiles/desktop-gnome.nix
    
    ../../modules/core
    ../../modules/hardware
    ../../modules/features
  ];

  system.stateVersion = "25.11";
  networking.hostName = "yoga";

  core.locale.timeZone = "Europe/Berlin";
  
  features.desktop-gnome.autoLoginUser = "dk";
  
  hardware.amd-gpu.enable = true;
  
  features = {
    filesystem = {
      type = "btrfs";
      enableFstrim = false;
      btrfs = {
        autoScrub = true;
        scrubFilesystems = [ "/" ];
        autoBalance = true;
      };
    };
    kernel.variant = "zen";
    kmscon.enable = true;
    virtualization.enable = false;
    zram.memoryPercent = 100;
  };

  boot.kernelModules = [ "ryzen_smu" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.ryzen-smu ];

  fileSystems = {
    "/".options = btrfsOpts;
    "/home".options = btrfsOpts;
    "/nix".options = btrfsOpts;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images 0711 root root - -"
    "h /var/lib/libvirt/images - - - - +C"
  ];

  features.kernel.extraParams = [
    "amd_pstate=active"
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.dcdebugmask=0x10"
  ];

  features.power-tlp.settings = {
    TLP_DEFAULT_MODE = "BAT";
    TLP_PERSISTENT_DEFAULT = 1;
    CPU_DRIVER_OPMODE_ON_AC = "active";
    CPU_DRIVER_OPMODE_ON_BAT = "active";
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    PLATFORM_PROFILE_ON_AC = "performance";
    PLATFORM_PROFILE_ON_BAT = "balanced";
    PCIE_ASPM_ON_BAT = "powersupersave";
    USB_AUTOSUSPEND = 1;
    USB_EXCLUDE_AUDIO = 1;
  };

  services.ryzen-tdp = {
    enable = true;
    ac = { stapm = 54; fast = 60; slow = 54; temp = 95; };
    battery = { stapm = 18; fast = 25; slow = 18; temp = 75; };
  };

  services.irqbalance.enable = true;

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };
  
  services.journald.extraConfig = "SystemMaxUse=200M";

  environment.systemPackages = with pkgs; [
    libva-utils 
    vulkan-tools 
    sbctl
  ];
}
