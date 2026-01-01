{ config, pkgs, inputs, lib, palette, ... }:

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
    
    ../../modules/core/boot.nix
    ../../modules/core/locale.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix.nix
    ../../modules/core/users.nix
    
    ../../modules/hardware/amd-gpu.nix
    
    ../../modules/features/bluetooth.nix
    ../../modules/features/desktop-gnome.nix
    ../../modules/features/filesystem.nix
    ../../modules/features/fonts.nix
    ../../modules/features/kernel.nix
    ../../modules/features/kmscon.nix
    ../../modules/features/power-tlp.nix
    ../../modules/features/virtualization.nix
    ../../modules/features/zram.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = "yoga";

  # Lanzaboote (Secure Boot)
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Core Configuration
  core.boot.silent = true;
  core.locale.timeZone = "Europe/Berlin";
  core.nix.gc.automatic = true;

  # Hardware
  hardware.amd-gpu.enable = true;

  # Features
  features = {
    bluetooth.enable = true;
    
    desktop-gnome = {
      enable = true;
      autoLogin = true;
      autoLoginUser = "dk";
    };
    
    filesystem = {
      type = "btrfs";
      optimizations = btrfsOpts;
    };
    
    fonts.enable = true;
    
    kernel = {
      variant = "zen";
      extraParams = [
        "amd_pstate=active"
        "amdgpu.ppfeaturemask=0xffffffff"
        "amdgpu.dcdebugmask=0x10"
      ];
    };
    
    kmscon.enable = true;
    
    power-tlp = {
      enable = true;
      settings = {
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
    };
    
    virtualization = {
      enable = true;
      spice = true;
    };
    
    zram = {
      enable = true;
      memoryPercent = 100;
    };
  };

  # AMD-specific kernel modules
  boot.extraModulePackages = [ config.boot.kernelPackages.ryzen-smu ];
  boot.kernelModules = [ "ryzen_smu" ];

  # Hardware enablement
  services.irqbalance.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Btrfs filesystem optimizations
  fileSystems."/" = {
    options = btrfsOpts;
  };
  fileSystems."/home" = {
    options = btrfsOpts;
  };
  fileSystems."/nix" = {
    options = btrfsOpts;
  };

  # Btrfs maintenance
  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images 0711 root root - -"
    "h /var/lib/libvirt/images - - - - +C"
  ];

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  systemd.services.btrfs-balance = {
    description = "Run monthly Btrfs balance";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=10 -musage=10 /";
    };
  };

  systemd.timers.btrfs-balance = {
    description = "Run monthly Btrfs balance";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "btrfs-balance.service";
    };
  };

  # Ryzen TDP control
  services.ryzen-tdp = {
    enable = true;
    ac = { 
      stapm = 54; 
      fast = 60; 
      slow = 54; 
      temp = 95; 
    };
    battery = { 
      stapm = 18; 
      fast = 25; 
      slow = 18; 
      temp = 75; 
    };
  };

  # Additional services
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };

  services.system76-scheduler.enable = true;
  
  services.journald.extraConfig = "SystemMaxUse=200M";

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Thermald
  services.thermald.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    libva-utils 
    vulkan-tools 
    sbctl
  ];
}
