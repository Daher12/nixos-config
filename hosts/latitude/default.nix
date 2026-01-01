{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
    
    ../../modules/core/boot.nix
    ../../modules/core/locale.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix.nix
    ../../modules/core/users.nix
    
    ../../modules/hardware/intel-gpu.nix
    ../../modules/hardware/nvidia-disable.nix
    
    ../../modules/features/bluetooth.nix
    ../../modules/features/desktop-gnome.nix
    ../../modules/features/filesystem.nix
    ../../modules/features/fonts.nix
    ../../modules/features/kernel.nix
    ../../modules/features/power-tlp.nix
    ../../modules/features/network-optimization.nix
    ../../modules/features/virtualization.nix
    ../../modules/features/zram.nix
  ];

  system.stateVersion = "25.05";
  networking.hostName = "e7450-nixos";

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
  hardware.intel-gpu.enable = true;
  hardware.nvidia-disable.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Features
  features = {
    bluetooth.enable = true;
    
    desktop-gnome = {
      enable = true;
      autoLogin = true;
      autoLoginUser = "dk";
    };
    
    filesystem = {
      type = "ext4";
      optimizations = [ "noatime" "nodiratime" "commit=30" ];
    };
    
    fonts.enable = true;
    
    kernel = {
      variant = "zen";
      extraParams = [
        "i915.enable_fbc=1"
        "i915.fastboot=1"
        "pcie_aspm=force"
        "mem_sleep_default=deep"
        "zswap.enabled=0"
      ];
    };
    
    power-tlp = {
      enable = true;
      settings = {
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
        USB_AUTOSUSPEND = 1;
        USB_EXCLUDE_BTUSB = 0;
      };
    };

    network-optimization.enable = true;
    
    virtualization = {
      enable = false;
      spice = false;
    };
    
    zram = {
      enable = true;
      memoryPercent = 50;
    };
  };

  # Ext4 filesystem optimizations
  fileSystems."/" = {
    options = lib.mkAfter config.features.filesystem.optimizations;
  };

  # Console fixes (manually embedded - KMSCon not used on latitude)
  console.useXkbConfig = true;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Power Management
  services.thermald.enable = true;

  # Custom Service: Fix Suspend Battery Drain (USB Wakeups)
  systemd.services.disable-wakeup-sources = {
    description = "Disable spurious wakeups from USB to save power";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "disable-wakeups" ''
        disable_wakeup() {
          if grep -q "^$1.*enabled" /proc/acpi/wakeup; then
            echo $1 > /proc/acpi/wakeup
          fi
        }
        disable_wakeup EHC1
        disable_wakeup XHC 
      '';
    };
  };

  # System76 Scheduler
  services.system76-scheduler = {
    enable = true;
    useStockConfig = true;
    settings.processScheduler.foregroundBoost.enable = true;
  };

  # Preload-NG (SSD optimization)
  services.preload-ng = {
    enable = true;
    settings = {
      sortStrategy = 0;
      memTotal = -10;
      memFree = 50;
      minSize = 2000000;
      cycle = 30;
    };
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Log compression
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    Compress=yes
  '';

  # System packages
  environment.systemPackages = with pkgs; [
    libva-utils 
    sbctl
  ];
}
