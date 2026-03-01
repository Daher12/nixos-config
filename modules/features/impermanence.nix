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

  # Derive the systemd device-unit name using utils.escapeSystemdPath.
  # Hand-building "dev-mapper-${name}.device" from the path tail is fragile:
  # systemd escapes slashes and special chars; utils.escapeSystemdPath matches
  # the actual unit name systemd generates for a given device path.
  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.features.impermanence = {
    enable = lib.mkEnableOption "Btrfs root wipe on boot";
    device = lib.mkOption {
      type = lib.types.str;
      description = "Mapped LUKS block device, e.g. /dev/mapper/cryptroot";
      example = "/dev/mapper/cryptroot";
    };
  };

  config = lib.mkIf cfg.enable {
    # initrd-nixos-activation chroots into /sysroot and executes binaries from
    # /nix/store. With split subvolumes, /sysroot/nix and /sysroot/persist must
    # be mounted before activation starts. neededForBoot = true generates the
    # mount units, but using RequiresMountsFor avoids guessing their exact names.
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
        # Systemd initrd is required for boot.initrd.systemd.services.
        # Without it, the wipe-root service is silently ignored.
        assertion = config.boot.initrd.systemd.enable;
        message = "features.impermanence requires boot.initrd.systemd.enable = true.";
      }
      {
        # Device unit name derivation assumes /dev/mapper/* path.
        # Anything else (raw /dev/sdX, etc.) will produce a wrong unit name.
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
      ];

      services.wipe-root = {
        description = "Wipe Btrfs @ subvolume";
        wantedBy = [ "initrd-root-fs.target" ];
        before = [
          "sysroot.mount"
          "initrd-root-fs.target"
        ];
        after = [ deviceUnit ];
        requires = [ deviceUnit ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
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

          if btrfs subvolume show /btrfs/@ >/dev/null 2>&1; then
            # @ is confirmed to be a subvolume - safe to recurse.
            delete_subvolume_recursively /btrfs/@
          elif [ -e /btrfs/@ ]; then
            # @ exists but is not a subvolume - this is unexpected and dangerous.
            # Bail out rather than risk deleting unrelated subvolumes via `list -o`.
            echo "ERROR: /btrfs/@ exists but is not a Btrfs subvolume" >&2
            umount /btrfs
            exit 1
          fi
          # If /btrfs/@ does not exist at all, this is a first boot - skip deletion.

          btrfs subvolume create /btrfs/@

          mount -t btrfs -o subvol=@ "${cfg.device}" /newroot

          # Create required top-level directories on the fresh subvolume.
          # /tmp: must exist with sticky bit; early-boot services fail before tmpfiles runs.
          # /var/log: journal writes here before impermanence stage-2; absence loses first-boot logs.
          mkdir -p /newroot/{nix,persist,boot,home,etc,tmp,var/log,var/lib/sops-nix,var/lib/sbctl}
          chmod 1777 /newroot/tmp

          umount /newroot
          umount /btrfs
        '';
      };
    };
  };
}