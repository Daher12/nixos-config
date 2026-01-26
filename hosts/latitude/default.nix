# hosts/latitude/default.nix
{ pkgs, lib, ... }:

let
  # Firmware-defined ACPI tokens from /proc/acpi/wakeup
  # Latitude E7450 typically uses EHC1 (USB2) and XHC (USB3)
  usbWakeDevices = [ "EHC1" "XHC" ];

  disableUsbWakeups = pkgs.writeShellScript "disable-usb-wakeups" ''
    set -euo pipefail
    wake=/proc/acpi/wakeup
    [[ -w "$wake" ]] || exit 0

    disable_dev() {
      local dev="$1"
      # Toggle only if currently enabled (idempotent safe-guard)
      if grep -qE "^${dev}[[:space:]].*enabled" "$wake"; then
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
  core.locale.timeZone = "Europe/Berlin";

  hardware.intel-gpu.enable = true;
  hardware.nvidia.disable.enable = true;

  features = {
    filesystem = {
      type = "ext4";
      mountOptions."/" = [ "noatime" "nodiratime" "commit=30" ];
    };

    kernel.extraParams = [
      "i915.enable_fbc=1"
      "i915.fastboot=1"
      "pcie_aspm=force"
      "mem_sleep_default=deep"
      "zswap.enabled=0"
    ];

    # Required: oomd is NOT enabled by the laptop profile
    oomd.enable = true;

    power-tlp.settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      USB_EXCLUDE_BTUSB = 0;
    };
  };

  systemd.services.disable-usb-wakeup-sources = {
    description = "Disable spurious wakeups from USB to save power";
    wantedBy = [ "multi-user.target" ];
    # Removed udev-settle dependency for faster boot
    serviceConfig = {
      Type = "oneshot";
      # Removed RemainAfterExit=true to allow re-execution on udev changes
      ExecStart = disableUsbWakeups;
    };
  };

  services = {
    # Re-apply after USB topology changes; /proc/acpi/wakeup toggles are not persistent
    udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}+="disable-usb-wakeup-sources.service"
    '';

    thermald.enable = true;

    preload-ng = {
      enable = true;
      settings = {
        cycle = 30;            # Data gathering/prediction quantum (seconds)
        useCorrelation = true; # Use correlation coefficient for more accurate predictions
        minSize = 2000000;     # Min sum of mapped memory (bytes) to track an app
        memTotal = -10;        # Percentage of total RAM to subtract from budget
        memFree = 50;          # Percentage of currently free RAM preload can use
        sortStrategy = 0;      # 0=SORT_NONE: Optimal for Flash/SSD storage
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
