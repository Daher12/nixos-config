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
      description = "UID for NFS anon mapping (fleet standard, pinned with the host user uid)";
    };
    nfsAnonGid = lib.mkOption {
      type = lib.types.int;
      default = 982;
      description = "GID for NFS anon mapping";
    };

    ports = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = {
        audiobookshelf = 13378;
        cadvisor = 8080;
        dockerMetrics = 9323;
        grafana = 3001;
        jellyfin = 8096;
      };
      description = ''
        Fleet media-stack service ports: single source for the host's docker
        binds, Caddy targets and Prometheus scrape configs (previously
        repeated as literals across hosts/nix-media/{docker,caddy,monitoring}.nix).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      # Relies on firewall/Tailscale for access control
      exports = ''
        /mnt/storage *(rw,async,crossmnt,fsid=0,no_subtree_check,root_squash,all_squash,anonuid=${toString cfg.nfsAnonUid},anongid=${toString cfg.nfsAnonGid})
      '';
    };
  };
}
