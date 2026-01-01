{ config, lib, ... }:

let
  cfg = config.core.networking;
in
{
  options.core.networking = {
    backend = lib.mkOption {
      type = lib.types.enum [ "iwd" "wpa_supplicant" ];
      default = "iwd";
      description = "WiFi backend for NetworkManager";
    };

    enablePowersave = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable WiFi power saving";
    };
  };

  config = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = cfg.backend;
      wifi.powersave = cfg.enablePowersave;
      dns = "systemd-resolved";
    };

    services.resolved = {
      enable = true;
      extraConfig = ''
        DNSStubListener=yes
        Cache=yes
        CacheFromLocalhost=yes
        DNSOverTLS=no
      '';
    };

    networking = {
      nameservers = [ ];
      firewall.checkReversePath = "loose";
    };
}
