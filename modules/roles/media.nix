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
    nfsAnonGid = lib.mkOption {
      type = lib.types.int;
      default = 982;
      description = "GID for NFS anon mapping";
    };
  };

  config = lib.mkIf cfg.enable {
    # Centralized NFS configuration
    services.nfs.server = {
      enable = true;
      # Relies on firewall/Tailscale for access control
      exports = ''
        /mnt/storage *(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash,all_squash,anonuid=${toString cfg.nfsAnonUid},anongid=${toString cfg.nfsAnonGid})
      '';
    };
  };
}
