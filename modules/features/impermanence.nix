{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.impermanence;
  luksName = lib.last (lib.splitString "/" cfg.device);
in
{
  # Import upstream unconditionally so options always exist
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.features.impermanence = {
    enable = lib.mkEnableOption "Btrfs root wipe on boot";
    device = lib.mkOption {
      type = lib.types.str;
      description = "The mapped device";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.fileSystems."/".fsType == "btrfs";
        message = "Impermanence module requires a Btrfs root filesystem.";
      }
    ];

    boot.initrd.systemd.services.wipe-root = {
      description = "Wipe Btrfs @ subvolume";
      wantedBy = [ "initrd-root-fs.target" ];
      before = [ "sysroot.mount" ];
      after = lib.optional (lib.hasPrefix "/dev/mapper/" cfg.device) "systemd-cryptsetup@${luksName}.service";
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      path = with pkgs; [
        btrfs-progs
        coreutils
        util-linux
        bash
      ];
      script = ''
        set -euo pipefail
        mkdir -p /btrfs /newroot
        mount -t btrfs -o subvolid=5 "${cfg.device}" /btrfs

        delete_subvolume_recursively() {
          local target="$1"
          local child
          while read -r child; do
            delete_subvolume_recursively "/btrfs/$child"
          done < <(btrfs subvolume list -o "$target" | cut -f 9- -d ' ')
          btrfs subvolume delete "$target" || true
        }

        if [ -d /btrfs/@ ]; then delete_subvolume_recursively /btrfs/@; fi

        btrfs subvolume create /btrfs/@

        mount -t btrfs -o subvol=@ "${cfg.device}" /newroot
        mkdir -p /newroot/{nix,persist,boot,home,etc,var/lib/sops-nix}

        umount /newroot
        umount /btrfs
      '';
    };
  };
}
