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

    dns = lib.mkOption {
      type = lib.types.enum [ "systemd-resolved" "dnsmasq" "none" ];
      default = "systemd-resolved";
      description = "DNS resolver backend";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "1.1.1.1" "8.8.8.8" ];
      description = "Static nameservers (empty = use DHCP)";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.dns == "systemd-resolved" -> config.services.resolved.enable;
        message = "systemd-resolved must be enabled when dns backend is systemd-resolved";
      }
    ];

    networking.networkmanager = {
      enable = true;
      wifi.backend = cfg.backend;
      wifi.powersave = cfg.enablePowersave;
      dns = cfg.dns;
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

    networking = {
      nameservers = cfg.nameservers;
      firewall.checkReversePath = "loose";
    };
  };
}
