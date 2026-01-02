{ config, lib, pkgs, ... }:

let
  cfg = config.features.filesystem;
in
{
  options.features.filesystem = {
    type = lib.mkOption {
      type = lib.types.enum [ "ext4" "btrfs" "xfs" "zfs" ];
      default = "ext4";
      description = "Primary filesystem type";
    };

    mountOptions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      example = {
        "/" = [ "noatime" "compress=zstd:3" ];
        "/home" = [ "noatime" "compress=zstd:1" ];
      };
      description = "Mount options per filesystem";
    };

    enableFstrim = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable periodic TRIM (disable if using discard=async)";
    };

    btrfs = {
      autoScrub = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable automatic Btrfs scrubbing";
      };

      scrubFilesystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/" ];
        description = "Filesystems to scrub";
      };

      autoBalance = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable monthly Btrfs balance";
      };

      defaultMountOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "compress-force=zstd:1"
          "noatime"
          "nodiratime"
          "discard=async"
          "space_cache=v2"
        ];
        description = "Default mount options for Btrfs filesystems";
      };
    };
  };

  config = lib.mkMerge [
    # Set sensible defaults based on filesystem type
    (lib.mkIf (cfg.type == "btrfs") {
      features.filesystem.enableFstrim = lib.mkDefault false;
      features.filesystem.btrfs.autoScrub = lib.mkDefault true;
      features.filesystem.btrfs.autoBalance = lib.mkDefault true;
    })

    {
      fileSystems = lib.mkMerge (
        lib.mapAttrsToList (path: opts: {
          ${path}.options = lib.mkAfter opts;
        }) cfg.mountOptions
      );
    }

    (lib.mkIf cfg.enableFstrim {
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    })

    (lib.mkIf (cfg.type == "btrfs" && cfg.btrfs.autoScrub) {
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = cfg.btrfs.scrubFilesystems;
        interval = "monthly";
      };
    })

    (lib.mkIf (cfg.type == "btrfs" && cfg.btrfs.autoBalance) {
      systemd.services.btrfs-balance = {
        description = "Monthly Btrfs balance";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.btrfs-progs "btrfs"} balance start -dusage=10 -musage=10 /";
        };
      };

      systemd.timers.btrfs-balance = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "monthly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
