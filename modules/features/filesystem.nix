{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.filesystem;
  
  # Optimized async discard detection
  hasAsyncDiscard = cfg.type == "btrfs" && 
    lib.any (lib.hasInfix "discard=async") (lib.flatten (lib.attrValues cfg.mountOptions));
in
{
  options.features.filesystem = {
    type = lib.mkOption {
      type = lib.types.enum [
        "ext4"
        "btrfs"
        "xfs"
        "zfs"
      ];
      default = "ext4";
      description = "Primary filesystem type";
    };

    mountOptions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        "/" = [
          "noatime"
          "compress=zstd:3"
        ];
        "/home" = [
          "noatime"
          "compress=zstd:1"
        ];
      };
      description = "Mount options per filesystem";
    };

    enableFstrim = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable periodic TRIM. Auto-detects: disabled for btrfs with discard=async";
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
          "ssd"
        ];
        description = "Default mount options for Btrfs filesystems";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.type == "btrfs") {
      features.filesystem = {
        btrfs.autoScrub = lib.mkDefault true;
        btrfs.autoBalance = lib.mkDefault true;
        # Auto-apply default btrfs mount options to all btrfs filesystems
        mountOptions = lib.mkDefault (
          lib.mapAttrs 
            (_: fsCfg: cfg.btrfs.defaultMountOptions) 
            (lib.filterAttrs (_: fsCfg: fsCfg.fsType or "" == "btrfs") config.fileSystems)
        );
      };
    })

    {
      # Merge feature-defined mount options with existing hardware-defined ones
      fileSystems = lib.mapAttrs (path: fsCfg: {
        options = lib.mkAfter (cfg.mountOptions.${path} or []);
      }) config.fileSystems;
    }

    {
      # Simplified auto-detect fstrim enablement
      services.fstrim.enable = cfg.enableFstrim or !hasAsyncDiscard;
      services.fstrim.interval = lib.mkIf config.services.fstrim.enable "weekly";
    }

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
          ExecStart = lib.concatMapStringsSep " && " (fs:
            "${lib.getExe' pkgs.btrfs-progs "btrfs"} balance start -dusage=10 -musage=10 ${fs}"
          ) cfg.btrfs.scrubFilesystems;
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
