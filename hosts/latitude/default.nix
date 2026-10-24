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

  # SecureBoot note: it is on via profiles/laptop.nix's mkDefault, and the
  # machine was ADOPTED (not installed from this flake) — confirm once on
  # the box with `sbctl status` that keys exist / are enrolled in
  # /var/lib/sbctl. Building .#latitude from another machine requires that
  # machine to have the sbctl keystore (lanzaboote consumes it at build
  # time).

  # Declarative SSH trust: yoga's key (fleet access was purely imperative
  # before 2026-10-19 — the repo managed no authorized_keys at all).
  # Additive to any imperative ~/.ssh/authorized_keys (see the option's
  # description in modules/core/users.nix).
  core.users.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE900h7UUGyAcICSsxmX2xqEDcF1PTkonC/r9l3xroES dk@yoga"
  ];

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
    # Tuning-history note (2026-10-24): pcie_aspm=force, i915.enable_fbc=1,
    # zswap.enabled=0 and the CPU_ENERGY_PERF_POLICY_* pair were removed.
    # force-ASPM is a documented hang source on 2015-era firmware (kernel
    # docs), fbc/zswap restated kernel defaults, and EPP needs HWP — this
    # Broadwell has none, and the x86_energy_perf_policy fallback tool was
    # never installed, so the policy lines did nothing. i915.fastboot and
    # mem_sleep_default=deep are kept deliberately.
    kernel.extraParams = [
      "i915.fastboot=1"
      "mem_sleep_default=deep"
    ];
    power-tlp.settings = {
      USB_EXCLUDE_BTUSB = 0;
    };
  };
  # Host-specific quirk: Disable spurious wakeups from USB to save power.
  # multi-user at boot + resume.target after every suspend: some Dell ECs
  # re-arm wakeup sources across suspend cycles. (The old
  # `after = systemd-udev-settle` was a no-op — that unit is deprecated and
  # nothing pulls it in.)
  systemd.services.disable-wakeup-sources = {
    description = "Disable spurious wakeups from USB (EHC1/XHC)";
    wantedBy = [
      "multi-user.target"
      "resume.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = disableUsbWakeups;
    };
  };

  # Firewall hardening (default-deny input, mgmt-LAN SSH, nftables backend)
  # comes from profiles/laptop.nix.
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

    journald.extraConfig = "SystemMaxUse=100M";
  };

  # --- Swap ---
  # Disk overflow for zram (priority below zramSwap's 10, same pattern as
  # yoga): the fleet already learned on yoga that zram-only swap with oomd's
  # ManagedOOMSwap=kill ends in killed sessions, not slowness — and this is
  # the smaller-RAM host. Plain file on the ext4 root; no hibernation here,
  # so no offset bookkeeping.
  swapDevices = [
    {
      device = "/var/lib/swap/swapfile";
      size = 8 * 1024; # MiB
    }
  ];
}
