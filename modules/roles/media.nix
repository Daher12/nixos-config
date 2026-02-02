# modules/roles/media.nix
{ config, lib, ... }:

let
  cfg = config.roles.media;
in
{
  options.roles.media = {
    enable = lib.mkEnableOption "media role";

    nfsAnonUid = lib.mkOption {
      type = lib.types.int;
      default = 1001;
      description = "UID for NFS anon mapping (estate standard)";
    };

    dockerUid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Docker container UID (must match NFS export)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dockerUid != null;
        message = "roles.media.dockerUid must be set (matches NFS export mapping)";
      }
      {
        assertion = cfg.dockerUid == cfg.nfsAnonUid;
        message = "roles.media.dockerUid must equal nfsAnonUid for NFS permissions";
      }
    ];
  };
}
