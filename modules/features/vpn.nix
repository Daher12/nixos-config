{ config, lib, ... }:

let
  cfg = config.features.vpn;
in
{
  options.features.vpn = {
    tailscale = {
      enable = lib.mkEnableOption "Tailscale VPN service";

      routingFeatures = lib.mkOption {
        type = lib.types.enum [ "none" "client" "server" "both" ];
        default = "client";
        description = "Routing features to enable (client/server)";
      };

      trustInterface = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Add tailscale0 to trusted firewall interfaces";
      };
    };
  };

  config = lib.mkIf cfg.tailscale.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.tailscale.routingFeatures;
    };

    networking.firewall.trustedInterfaces = 
      lib.mkIf cfg.tailscale.trustInterface [ "tailscale0" ];
  };
}
