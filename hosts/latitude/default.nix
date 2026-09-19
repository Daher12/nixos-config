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
  core = {
    users = {
      description = "David";
      defaultShell = "fish";
    };
    boot = {
      plymouth.theme = "bgrt";
      tmpfs = {
        enable = true;
        size = "2G";
      };
    };
    openssh.enable = true;
  };

  hardware = {
    intel-gpu.enable = true;
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

    # serverIp uses the features.nas option default (Tailscale IP of nix-media)
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

  # Mirror of yoga's firewall hardening: default-deny input, SSH only from
  # the home management LAN (192.168.88.0/24). tailscale0 stays trusted via
  # features.vpn.tailscale.trustInterface (laptop profile) — that remains
  # the remote-management path on foreign networks. Port 22 must NOT
  # re-enter allowedTCPPorts; that would re-open it on every interface.
  # NOTE: extraInputRules is nftables-ONLY — silently ignored when the
  # iptables backend is active.
  networking = {
    nftables.enable = true;
    firewall = {
      allowPing = true;
      extraInputRules = ''
        ip saddr 192.168.88.0/24 tcp dport 22 ct state new accept comment "ssh from home management LAN"
      '';
    };
  };
  services = {
    # thermald comes from hardware.intel-gpu (mkDefault)

    # sshd hardening via core.openssh (PasswordAuthentication=no,
    # PermitRootLogin=no, UseDns=no); port 22 handled by extraInputRules above.
    openssh.openFirewall = false;
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
