{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];
  system.stateVersion = "25.11";

  core.locale.timeZone = "Europe/Berlin";
  core.users.description = "David";

  hardware.amd-gpu.enable = true;
  features = {
    filesystem = {
      type = "btrfs";
      # Explicitly apply defaults to specific paths
      mountOptions = {
        "/" = config.features.filesystem.btrfs.defaultMountOptions;
        "/home" = config.features.filesystem.btrfs.defaultMountOptions;
        "/nix" = config.features.filesystem.btrfs.defaultMountOptions;
      };
      btrfs = {
        autoScrub = true;
        scrubFilesystems = [ "/" ];
        autoBalance = true;
      };
    };

    kernel.extraParams = [
      "zswap.enabled=0"
      "amd_pstate=active"
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.dcdebugmask=0x10"
    ];
    kmscon.enable = true;

    oomd.enable = true;

    virtualization = {
      enable = true;
      includeGuestTools = true;
      windows11.enable = true;
    };

    power-tlp.settings = {
      TLP_DEFAULT_MODE = "BAT";
      TLP_PERSISTENT_DEFAULT = 1;
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_SCALING_MIN_FREQ_ON_AC = 403730;
      CPU_SCALING_MIN_FREQ_ON_BAT = 403730;
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
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

  systemd.services.nix-daemon.serviceConfig.CPUQuota = "${
    toString (config.nix.settings.cores * 100)
  }%";

  services.irqbalance.enable = true;

  services.journald.extraConfig = "SystemMaxUse=200M";
  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    sbctl
  ];
}
