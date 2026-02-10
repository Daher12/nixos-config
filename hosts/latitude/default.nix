{ pkgs, lib, mainUser, ... }:

let
  # Firmware-defined ACPI tokens from /proc/acpi/wakeup
  # Latitude E7450 typically uses EHC1 (USB2) and XHC (USB3)
  usbWakeDevices = [
    "EHC1"
    "XHC"
  ];

  disableUsbWakeups = pkgs.writeShellScript "disable-usb-wakeups" ''
    set -euo pipefail
    wake=/proc/acpi/wakeup
    [[ -w "$wake" ]] ||
    exit 0

    disable_dev() {
      local dev="$1"
      # Toggle only if currently enabled (idempotent safe-guard)
      if grep -qE "^$dev[[:space:]].*enabled" "$wake";
      then
        echo "Disabling wakeup for $dev"
        echo "$dev" > "$wake"
      fi
    }

    ${lib.concatStringsSep "\n" (map (d: "disable_dev ${lib.escapeShellArg d}") usbWakeDevices)}
  '';
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.05";
  users.users.${mainUser}.uid = 1000
  core.users.description = "David";
  core.locale.timeZone = "Europe/Berlin";

  networking.hosts = {
    "100.123.189.29" = [ "nix-media" ];
  };

  hardware = {
    intel-gpu.enable = true;
    isPhysical = true;
    nvidia.disable.enable = true;
  };

  features = {
    filesystem = {
      type = "ext4";
      mountOptions."/" = [
        "noatime"
        "nodiratime"
        "commit=30"
      ];
    };

    nas.enable = true;

    desktop-gnome = {
      autoLogin = true;
    };

    kernel.extraParams = [
      "i915.enable_fbc=1"
      "i915.fastboot=1"
      "pcie_aspm=force"
      "mem_sleep_default=deep"
      "zswap.enabled=0"
    ];

    power-tlp.settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      USB_EXCLUDE_BTUSB = 0;
    };
  };

  # Host-specific quirk: Disable spurious wakeups from USB to save power
  systemd.services.disable-wakeup-sources = {
    description = "Disable spurious wakeups from USB (EHC1/XHC)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = disableUsbWakeups;
    };
  };

  services = {
    udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}+="disable-wakeup-sources.service"
    '';
    thermald.enable = true;

    preload-ng = {
      enable = true;
      settings = {
        sortStrategy = 0;
        memTotal = -10;
        memFree = 50;
        minSize = 2000000;
        cycle = 30;
      };
    };

    journald.extraConfig = ''
      SystemMaxUse=100M
      Compress=yes
    '';
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    sbctl
  ];
}
