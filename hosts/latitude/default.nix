{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../profiles/laptop.nix
    ../../profiles/desktop-gnome.nix

    ../../modules/core
    ../../modules/hardware
    ../../modules/features
  ];

  system.stateVersion = "25.05";

  core.locale.timeZone = "Europe/Berlin";

  features.desktop-gnome.autoLoginUser = "dk";

  hardware.intel-gpu.enable = true;
  hardware.nvidia-disable.enable = true;

  features = {
    filesystem = {
      type = "ext4";
      mountOptions."/" = [ "noatime" "nodiratime" "commit=30" ];
    };

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

    power-tlp.settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 0;
    };

    virtualization.enable = false;

    zram.memoryPercent = 50;
  };

  console.useXkbConfig = true;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Fix spurious USB wakeups draining battery during suspend
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

  services.system76-scheduler.settings.processScheduler.foregroundBoost.enable = true;
  
  services.thermald.enable = true;

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

  services.journald.extraConfig = ''
    SystemMaxUse=100M
    Compress=yes
  '';

  environment.systemPackages = with pkgs; [
    libva-utils
    sbctl
  ];
}
