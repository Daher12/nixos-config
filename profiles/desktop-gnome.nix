{ lib, ... }:

{
  features.desktop-gnome = {
    enable = lib.mkDefault true;
    autoLogin = lib.mkDefault true;
  };

  features.vpn.tailscale = {
    enable = lib.mkDefault true;
    routingFeatures = lib.mkDefault "client";
    trustInterface = lib.mkDefault true;
  };

  services.system76-scheduler = {
    enable = lib.mkDefault true;
    useStockConfig = lib.mkDefault true;
  };
}
