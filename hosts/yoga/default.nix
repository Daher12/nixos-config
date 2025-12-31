{ config, pkgs, inputs, lib, palette, pkgs-unstable, ... }:

let
  # Einmal definieren, mehrfach nutzen
  btrfsOpts = lib.mkAfter [ "compress-force=zstd:1" "noatime" "nodiratime" "discard=async" "space_cache=v2" ];
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
    ./hardware-configuration.nix
    ./modules/ryzen-tdp.nix
    ../../modules/common.nix
    ../../modules/fonts.nix
    ../../modules/console.nix
    ../../modules/gnome.nix
    ../../modules/virtualization.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = "yoga";

  # ===========================================================================
  # AMD & HARDWARE OPTIMIZATIONS
  # ===========================================================================
  
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
  boot.extraModulePackages = [ config.boot.kernelPackages.ryzen-smu ];
  boot.kernelModules = [ "ryzen_smu" ];
  
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.dcdebugmask=0x10"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Microcode wird bereits in hardware-configuration.nix gesetzt - hier entfernt!

  services.irqbalance.enable = true;
  
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
  
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "va_gl";
  };

  # ===========================================================================
  # FILESYSTEM & MAINTENANCE (BTRFS)
  # ===========================================================================
  
  fileSystems."/" = {
    options = btrfsOpts;
  };
  fileSystems."/home" = {
    options = btrfsOpts;
  };
  fileSystems."/nix" = {
    options = btrfsOpts;
  };

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

  # ===========================================================================
  # POWER MANAGEMENT
  # ===========================================================================
  
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.tlp = {
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

  # ===========================================================================
  # LOCAL SERVICES
  # ===========================================================================

  services.ryzen-tdp = {
    enable = true;
    ac      = { stapm = 54; fast = 60; slow = 54; temp = 95; };
    battery = { stapm = 18; fast = 25; slow = 18; temp = 75; };
  };

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };

  services.system76-scheduler.enable = true;
  services.journald.extraConfig = "SystemMaxUse=200M";
  
  environment.systemPackages = with pkgs; [
    libva-utils vulkan-tools sbctl
  ];
}
