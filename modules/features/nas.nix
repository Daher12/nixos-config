{
  config,
  lib,
  pkgs,
  ...
}:

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
      # Fleet constant: Tailscale IP of nix-media, the only NFS server.
      default = "100.123.189.29";
      description = "NFS Server IP or Hostname (e.g., Tailscale IP)";
      example = "100.123.189.29";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.features.vpn.tailscale.enable;
        message = "features.nas requires features.vpn.tailscale.enable = true";
      }
      {
        assertion = cfg.serverIp != "";
        message = "features.nas: serverIp must not be empty";
      }
    ];

    networking.hosts = {
      "${cfg.serverIp}" = [ "nix-media" ];
    };

    # Gate the mount on real Tailscale readiness, not network-online.target:
    # that target is hollow on NetworkManager hosts ever since
    # core.networking disabled NetworkManager-wait-online, and tailscaled
    # being "active" does not mean the tailnet is up either. The oneshot
    # below blocks until the backend actually reports Running; the mount
    # pulls it in via x-systemd.requires at first /mnt/nas access, so it
    # costs nothing at boot and tailscale-online's own requires/after
    # transitively order the mount after tailscaled.
    systemd.services.tailscale-online = {
      description = "Wait until the Tailscale backend reports Running";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "45s";
      };
      script = ''
        for _ in $(seq 1 30); do
          state=$(${lib.getExe pkgs.tailscale} status --json 2>/dev/null \
            | ${lib.getExe pkgs.jq} -r '.BackendState' 2>/dev/null || echo "")
          if [ "$state" = "Running" ]; then
            exit 0
          fi
          sleep 1
        done
        echo "tailscale-online: backend did not reach Running within 30s" >&2
        exit 1
      '';
    };

    fileSystems."${cfg.mountPoint}" = {
      device = "${cfg.serverIp}:/";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        "x-systemd.requires=tailscale-online.service"
        "x-systemd.after=tailscale-online.service"
        # Fail fast when the server is unreachable: on 2026-11-19 a
        # nixos-rebuild switch on nix-media left nfs-server stopped and the
        # default 90s mount timeout plus 60s/retrans timeo turned every
        # access (Nautilus bookmark, ls) into a multi-minute hang.
        # timeo=150 (15s) x retrans=2 errors out after ~30s;
        # mount-timeout caps the mount(8) itself at the same horizon.
        "x-systemd.mount-timeout=30s"
        "nfsvers=4.2"
        "soft"
        "timeo=150"
        "retrans=2"
        "_netdev"
      ];
    };
  };
}
