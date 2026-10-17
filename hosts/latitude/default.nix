{
  pkgs,
  lib,
  mainUser,
  ...
}:

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
    [[ -w "$wake" ]] || exit 0

    disable_dev() {
      local dev="$1"
      # Toggle only if currently enabled (idempotent safe-guard)
      if grep -qE "^$dev[[:space:]].*enabled" "$wake"; then
        echo "Disabling wakeup for $dev"
        echo "$dev" > "$wake"
      fi
    }

    ${lib.concatStringsSep "\n" (map (d: "disable_dev ${lib.escapeShellArg d}") usbWakeDevices)}
  '';
in
{
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.05";
  users.users.${mainUser}.uid = 1000;

  # --- Core Configuration ---
  # User description + SSH mgmt-LAN scoping (core.users.description,
  # core.openssh) come from profiles/laptop.nix; boot (bgrt, 2G tmpfs) and
  # the fish shell from the core module defaults.

  hardware = {
    intel-gpu.enable = true;
    # This unit has the optional NVIDIA dGPU (confirmed 2026-10-16):
    # nvidia-disable blacklists nouveau and strips the PCI device so the
    # dGPU stays powered down. Deliberate — do not remove.
    nvidia-disable.enable = true;
  };
  features = {
    # NOTE: dk_password_hash from secrets/hosts/latitude.yaml is load-bearing
    # (modules/core/users.nix wires it whenever sops is enabled). The file is
    # still encrypted to the retired admin key — re-encrypt per
    # SOPS_RUNBOOK.md §3 (drops the two dead wifi PSKs, keeps the hash).
    sops.enable = true;
    # Mount options live in ./disks.nix (single source with the layout).
    # ext4 here only steers features.filesystem's fstrim auto-detection.
    filesystem.type = "ext4";

    # nas + brave enables come from profiles/laptop.nix (fleet laptop
    # baseline).

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

  # Firewall hardening (default-deny input, mgmt-LAN SSH, nftables backend)
  # comes from profiles/laptop.nix — same values yoga had before the
  # 2026-10-17 dedup.
  services = {
    # thermald comes from hardware.intel-gpu (mkDefault)

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

  environment.systemPackages = [
    pkgs.libva-utils
  ];
}
