{ config, lib, ... }:

let
  cfg = config.features.filesystem;
in
{
  options.features.filesystem = {
    type = lib.mkOption {
      type = lib.types.enum [ "ext4" "btrfs" "xfs" ];
      default = "ext4";
      description = "Filesystem type (metadata only, does not configure mounts)";
    };

    optimizations = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "noatime" "nodiratime" ];
      description = "Mount options for filesystem optimization";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.type != null;
        message = "Filesystem type must be specified";
      }
    ];
  };
}
