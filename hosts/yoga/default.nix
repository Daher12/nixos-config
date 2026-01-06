{
  config,
  pkgs,
  lib,
  mainUser,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  core.locale.timeZone = "Europe/Berlin";

  features.desktop-gnome.autoLoginUser = mainUser;

  hardware.amd-gpu.enable = true;

  features = {
    filesystem = {
      type = "btrfs";
      btrfs = {
        autoScrub = true;
        scrubFilesystems = [ "/" ];
        autoBalance = true;
      };
    };

    kernel = {
      variant = "zen";
      extraParams = [
        "amd_pstate=active"
        "amdgpu.ppfeaturemask=0xffffffff"
        "amdgpu.dcdebugmask=0x10"
      ];
    };

    kmscon.enable = true;

    oomd.enable = true;

    virtualization = {
      enable = true;
      includeGuestTools = true;

      windows11 = {
        enable = true;
      };
    };

    zram.memoryPercent = 100;

    power-tlp.settings = {
      TLP_DEFAULT_MODE = "BAT";
      TLP_PERSISTENT_DEFAULT = 1;
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_MIN_FREQ_ON_AC = 403730;
      CPU_SCALING_MIN_FREQ_ON_BAT = 403730;
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PCIE_ASPM_ON_BAT = "powersupersave";
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_AUDIO = 1;
    };
  };

  fileSystems =
    let
      btrfsOpts = lib.mkAfter config.features.filesystem.btrfs.defaultMountOptions;
    in
    {
      "/".options = btrfsOpts;
      "/home".options = btrfsOpts;
      "/nix".options = btrfsOpts;
    };

  boot.kernelModules = [ "ryzen_smu" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.ryzen-smu ];

  hardware.ryzen-tdp = {
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

  systemd.services.nix-daemon.serviceConfig.CPUQuota = lib.mkForce "800%";

  services.irqbalance.enable = true;

  services.journald.extraConfig = "SystemMaxUse=200M";

  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    sbctl
  ];
}
