{ lib, mainUser, ... }:

{
  features.desktop-gnome = {
    enable = lib.mkDefault true;
    autoLogin = lib.mkDefault false;
    autoLoginUser = lib.mkDefault mainUser;
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
