{ config, lib, pkgs, ... }:

let
  cfg = config.features.network-optimization;
in
{
  options.features.network-optimization = {
    enable = lib.mkEnableOption "TCP/Network optimizations (BBR + FQ)";
    tcpCongestionControl = lib.mkOption {
      type = lib.types.str;
      default = "bbr";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tcp_${cfg.tcpCongestionControl}" ];
    
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = cfg.tcpCongestionControl;
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
  };
}
