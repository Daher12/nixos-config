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
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
 
  system.stateVersion = "25.11";
  core.locale.timeZone = "Europe/Berlin";
  core.users.description = "David";
  
  # ... [Existing networking, hardware, features config] ...

  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    sbctl
  ];

  # --- Impermanence & Disko Configuration ---

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;

  # Required: Inject HM module so 'home.persistence' is valid
  home-manager.sharedModules = [ inputs.impermanence.homeManagerModules.impermanence ];

  # Wipe ephemeral root subvolume (@) each boot
  boot.initrd.systemd.services.wipe-root = {
    description = "Wipe Btrfs @ subvolume (impermanent root)";
    wantedBy = [ "initrd-root-fs.target" ];
    before = [ "sysroot.mount" ];
    after = [
      "cryptsetup.target"
      "systemd-udev-settle.service"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    # Added bash for robustness with process substitution
    path = [ pkgs.bash pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux ];
    script = ''
      set -euo pipefail

      mkdir -p /btrfs /newroot

      # Mount top-level Btrfs (subvolid=5)
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

      # Ensure mountpoints exist inside the fresh root
      mount -t btrfs -o subvol=@ /dev/mapper/cryptroot /newroot
      mkdir -p /newroot/{nix,persist,boot,home}
      umount /newroot
      umount /btrfs
    '';
  };

  # Persisted system state
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
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  # Ensure persistent directories exist
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root - -"
    "d /persist/system 0755 root root - -"
    "d /persist/home 0755 root root - -"
    "d /persist/home/dk 0700 dk dk - -"
  ];
}
