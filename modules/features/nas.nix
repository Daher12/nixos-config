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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.features.vpn.tailscale.enable;
        message = "features.nas requires features.vpn.tailscale.enable = true";
      }
    ];

    fileSystems."${cfg.mountPoint}" = {
      device = "100.123.189.29:/mnt/storage";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        "x-systemd.requires=tailscaled.service"
        "x-systemd.after=tailscaled.service"
        "nfsvers=4.2"
        "soft"
        "timeo=30"
      ];
    };
  };
}
