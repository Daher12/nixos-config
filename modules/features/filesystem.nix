{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.filesystem;

  resolvedBalanceFs =
    if cfg.btrfs.balanceFilesystems != [ ] then
      cfg.btrfs.balanceFilesystems
    else
      cfg.btrfs.scrubFilesystems;
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
      description = "Primary filesystem type (informational — only Btrfs receives active tuning via this module)";
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

      balanceFilesystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Filesystems to balance (defaults to scrubFilesystems when empty)";
      };
    };
  };

  config = lib.mkMerge [
    # Btrfs defaults
    (lib.mkIf (cfg.type == "btrfs") {
      features.filesystem = {
        btrfs.autoScrub = lib.mkDefault true;
        btrfs.autoBalance = lib.mkDefault true;
      };
    })

    # Apply mount options
    {
      fileSystems = lib.mapAttrs (_: opts: {
        options = lib.mkAfter opts;
      }) cfg.mountOptions;
    }

    # Fstrim auto-detection (fixed for Disko)
    # Btrfs-specific computations deferred into branches to avoid unconditional
    # evaluation of config.fileSystems on non-btrfs hosts.
    {
      services.fstrim.enable =
        if cfg.enableFstrim != null then
          cfg.enableFstrim
        else if cfg.type != "btrfs" then
          true
        else
          (lib.attrNames (lib.filterAttrs (_: fs: (fs.fsType or null) == "btrfs") config.fileSystems) == [ ])
          || !lib.any (fs: lib.elem "discard=async" (fs.options or [ ])) (
            lib.attrValues (lib.filterAttrs (_: fs: (fs.fsType or null) == "btrfs") config.fileSystems)
          );

      services.fstrim.interval = lib.mkIf config.services.fstrim.enable "weekly";
    }

    # Btrfs scrub
    (lib.mkIf (cfg.type == "btrfs" && cfg.btrfs.autoScrub) {
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = cfg.btrfs.scrubFilesystems;
        interval = "monthly";
      };
    })

    # Btrfs balance
    (lib.mkIf (cfg.type == "btrfs" && cfg.btrfs.autoBalance) {
      systemd.services.btrfs-balance = {
        description = "Monthly Btrfs balance";
        after = [ "local-fs.target" ];
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail
          ${lib.concatMapStringsSep "\n" (
            fs: "${lib.getExe' pkgs.btrfs-progs "btrfs"} balance start -dusage=10 -musage=10 ${fs}"
          ) resolvedBalanceFs}
        '';
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
