{
  inputs,
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  cfg = config.features.impermanence;
  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.features.impermanence = {
    enable = lib.mkEnableOption "Btrfs root rollback on boot";

    device = lib.mkOption {
      type = lib.types.str;
      description = "Mapped LUKS block device, e.g. /dev/mapper/cryptroot";
      example = "/dev/mapper/cryptroot";
    };

    rootSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@";
      description = "Writable root subvolume mounted as /";
    };

    blankSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@blank";
      description = "Read-only template snapshot used to restore the root subvolume";
    };
  };

  config = lib.mkIf cfg.enable {
    # initrd-nixos-activation chroots into /sysroot and executes binaries from
    # /nix/store. With split subvolumes, /sysroot/nix and /sysroot/persist must
    # be mounted before activation starts.
    boot.initrd.systemd.services.initrd-nixos-activation = {
      after = [ "sysroot.mount" ];
      unitConfig.RequiresMountsFor = [
        "/sysroot/nix/store"
        "/sysroot/persist"
      ];
    };

    assertions = [
      {
        assertion = config.fileSystems."/".fsType == "btrfs";
        message = "features.impermanence requires a Btrfs root filesystem.";
      }
      {
        assertion = config.boot.initrd.systemd.enable;
        message = "features.impermanence requires boot.initrd.systemd.enable = true.";
      }
      {
        assertion = lib.hasPrefix "/dev/mapper/" cfg.device;
        message = "features.impermanence: device must be a /dev/mapper/* path, got: ${cfg.device}";
      }
    ];

    boot.initrd.systemd = {
      enable = true;

      storePaths = [
        "${pkgs.btrfs-progs}/bin/btrfs"
        "${pkgs.util-linux}/bin/mount"
        "${pkgs.util-linux}/bin/umount"
        "${pkgs.coreutils}/bin/chmod"
        "${pkgs.coreutils}/bin/test"
      ];

      services.rollback-root = {
        description = "Rollback Btrfs root subvolume from template snapshot";
        wantedBy = [ "initrd-root-device.target" ];
        before = [ "sysroot.mount" ];
        after = [ deviceUnit ];
        requires = [ deviceUnit ];

        unitConfig = {
          DefaultDependencies = "no";
          OnFailure = "emergency.target";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          set -euo pipefail

          ROOT="${cfg.rootSubvolume}"
          BLANK="${cfg.blankSubvolume}"

          mkdir -p /btrfs
          mount -t btrfs -o subvolid=5 "${cfg.device}" /btrfs

          delete_subvolume_recursively() {
            local target="$1"
            local child
            while read -r child; do
              delete_subvolume_recursively "/btrfs/$child"
            done < <(btrfs subvolume list -o "$target" | cut -f 9- -d ' ')
            btrfs subvolume delete "$target" || true
          }

          # The template snapshot must exist and be a real subvolume.
          if ! btrfs subvolume show "/btrfs/$BLANK" >/dev/null 2>&1; then
            echo "ERROR: missing template snapshot /btrfs/$BLANK" >&2
            umount /btrfs
            exit 1
          fi

          # Validate that the template already contains the mountpoints and dirs
          # expected during initrd activation and later boot.
          for d in \
            nix \
            persist \
            boot \
            home \
            etc \
            tmp \
            var \
            var/log \
            var/lib \
            var/lib/sops-nix \
            var/lib/sbctl
          do
            if [ ! -e "/btrfs/$BLANK/$d" ]; then
              echo "ERROR: template /btrfs/$BLANK is missing required path: /$d" >&2
              umount /btrfs
              exit 1
            fi
          done

          # Remove the current writable root if it exists.
          if btrfs subvolume show "/btrfs/$ROOT" >/dev/null 2>&1; then
            delete_subvolume_recursively "/btrfs/$ROOT"
          elif [ -e "/btrfs/$ROOT" ]; then
            echo "ERROR: /btrfs/$ROOT exists but is not a Btrfs subvolume" >&2
            umount /btrfs
            exit 1
          fi

          # Restore writable root from the known-good template snapshot.
          btrfs subvolume snapshot "/btrfs/$BLANK" "/btrfs/$ROOT"

          # Enforce sticky bit for /tmp even if template permissions drifted.
          chmod 1777 "/btrfs/$ROOT/tmp"

          umount /btrfs
        '';
      };
    };
  };
}