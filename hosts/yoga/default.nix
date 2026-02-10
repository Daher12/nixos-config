{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disks.nix
  ];

  # Preserve initrd essentials from old hardware-configuration
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "25.11";
  core.locale.timeZone = "Europe/Berlin";
  core.users.description = "David";

  networking.hosts = {
    "100.123.189.29" = [ "nix-media" ];
  };

  hardware = {
    amd-gpu.enable = true;
    amd-kvm.enable = true;
    ryzen-tdp = {
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
  };

  features = {
    nas.enable = true;
    desktop-gnome.autoLogin = true;
    sops.enable = true;
    filesystem = {
      type = "btrfs";
      btrfs = {
        autoScrub = true;
        scrubFilesystems = [ "/persist" ];
        autoBalance = true;
      };
    };
    kernel.extraParams = [
      "zswap.enabled=0"
      "amd_pstate=active"
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.dcdebugmask=0x10"
    ];
    oomd.enable = true;
    virtualization = {
      enable = true;
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
  boot.extraModulePackages = [ config.boot.kernelPackages."ryzen-smu" ];

  systemd.services.nix-daemon.serviceConfig =
    let
      cores = config.nix.settings.cores or 0;
    in
    lib.mkIf (cores > 0) { CPUQuota = "${toString (cores * 100)}%"; };

  services.irqbalance.enable = true;
  services.journald.extraConfig = "SystemMaxUse=200M";

  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    sbctl
  ];

  # --- Impermanence & Disko Configuration ---
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;

  programs.fuse.userAllowOther = true;
  environment.etc."machine-id".source = "/persist/etc/machine-id";
  home-manager.sharedModules = [ inputs.impermanence.homeManagerModules.impermanence ];

  boot.initrd.systemd.services.wipe-root = {
    description = "Wipe Btrfs @ subvolume (impermanent root)";
    wantedBy = [ "initrd-root-fs.target" ];
    before = [ "sysroot.mount" ];
    after = [
      "cryptsetup.target"
      "systemd-cryptsetup@cryptroot.service"
      "systemd-udev-settle.service"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.bash
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.util-linux
    ];
    script = ''
      set -euo pipefail
      mkdir -p /btrfs /newroot
      mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /btrfs

      delete_subvolume_recursively() {
        local target="$1"
        local child
        while read -r child; do
          delete_subvolume_recursively "/btrfs/$child"
        done < <(btrfs subvolume list -o "$target" | cut -f 9- -d ' ')
        btrfs subvolume delete "$target" || true
      }

      if [ -d /btrfs/@ ]; then
        delete_subvolume_recursively /btrfs/@
      fi

      btrfs subvolume create /btrfs/@
      mount -t btrfs -o subvol=@ /dev/mapper/cryptroot /newroot
      mkdir -p /newroot/{nix,persist,boot,home}
      umount /newroot
      umount /btrfs
    '';
  };

  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/iwd"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/tailscale"
      "/var/lib/sops-nix"
      "/var/lib/sbctl"
      "/var/lib/upower"
      "/var/lib/colord"
      "/var/db/sudo/lectured"
      "/var/lib/libvirt"
      "/var/lib/gdm"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /persist 0755 root root - -"
    "d /persist/system 0755 root root - -"
    "d /persist/home 0755 root root - -"
    "Z /persist/home/dk 0700 dk dk - -"
  ];
}
