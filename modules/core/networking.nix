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

    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.netdev_max_backlog" = 32768;
      "net.core.rmem_max" = 67108864;
      "net.core.wmem_max" = 67108864;
      "net.ipv4.tcp_rmem" = "4096 131072 67108864";
      "net.ipv4.tcp_wmem" = "4096 131072 67108864";
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_low_latency" = 1;
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_notsent_lowat" = 16384;
    };

    boot.kernelModules = [ "tcp_bbr" ];
  };
}
