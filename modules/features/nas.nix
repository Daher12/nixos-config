{ config, lib, ... }:

let
  cfg = config.features.nas;
in
{
  options.features.nas = {
    enable = lib.mkEnableOption "NFS mount via Tailscale";

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas";
      description = "Local mount point";
    };

    serverIp = lib.mkOption {
      type = lib.types.str;
      default = "100.123.189.29"; # Use hostname (Tailscale DNS) or the IP "100.123.189.29"
      description = "NFS Server IP or Hostname";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.features.vpn.tailscale.enable;
        message = "features.nas requires features.vpn.tailscale.enable = true";
      }
    ];

    fileSystems."${cfg.mountPoint}" = {
      device = "${cfg.serverIp}:/";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        # FIX: Wait for network AND tailscale to be fully ready
        "x-systemd.requires=network-online.target"
        "x-systemd.after=network-online.target"
        "x-systemd.requires=tailscaled.service"
        "x-systemd.after=tailscaled.service"
        "nfsvers=4.2"
        "soft"
        "timeo=30"
        "resvport"
        # FIX: Add retry logic for transient network issues
        "retrans=3"
        "_netdev"
      ];
    };

    # Ensure network-online.target is enabled
    systemd.targets.network-online.wantedBy = lib.mkForce [ "multi-user.target" ];
  };
}
