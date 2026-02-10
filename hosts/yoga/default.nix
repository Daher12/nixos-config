{
  # ... imports
  # ... inputs

  boot.initrd.systemd.services.wipe-root = {
    description = "Wipe Btrfs @ subvolume (impermanent root)";
    wantedBy = [ "initrd-root-fs.target" ];
    before = [ "sysroot.mount" ];
    after = [
      "cryptsetup.target"
      "systemd-cryptsetup@cryptroot.service"
      "systemd-udev-settle.service"
    ];
    # ISSUE 1: Ensure crypt device is active before attempting mount
    requires = [ "systemd-cryptsetup@cryptroot.service" ];
    
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

      # ISSUE 2: Verify mount success before destructive operations
      if ! mountpoint -q /btrfs; then
        echo "Failed to mount /btrfs, halting wipe to prevent data loss."
        exit 1
      fi

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
      # ISSUE 3: Critical desktop state state
      "/var/lib/AccountsService"
      "/var/lib/fwupd"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /persist 0755 root root - -"
    "d /persist/system 0755 root root - -"
    "d /persist/home 0755 root root - -"
    "d /persist/etc 0755 root root - -"
    "Z /persist/home/dk 0700 dk dk - -"
  ];
}
