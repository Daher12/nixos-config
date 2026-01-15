# modules/core/networking.nix
{ config, lib, ... }:

let
  cfg = config.core.networking;
in
{
  options.core.networking = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "iwd"
        "wpa_supplicant"
      ];
      default = "iwd";
      description = "WiFi backend for NetworkManager";
    };

    enablePowersave = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable WiFi power saving";
    };

    dns = lib.mkOption {
      type = lib.types.enum [
        "systemd-resolved"
        "dnsmasq"
        "none"
      ];
      default = "systemd-resolved";
      description = "DNS resolver backend";
    };
  };

  config = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = cfg.backend;
      wifi.powersave = cfg.enablePowersave;
      inherit (cfg) dns;
    };

    services.resolved = lib.mkIf (cfg.dns == "systemd-resolved") {
      enable = true;
      extraConfig = ''
        DNSStubListener=yes
        Cache=yes
        CacheFromLocalhost=yes
        DNSOverTLS=no
      '';
    };
  };
}
