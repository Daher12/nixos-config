{ config, lib, ... }:

let
  cfg = config.core.sysctl;
in
{
  options.core.sysctl = {
    optimizeForServer = lib.mkEnableOption "server-oriented sysctl defaults";
  };

  config = lib.mkIf cfg.optimizeForServer {
    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault 10;
      "vm.vfs_cache_pressure" = lib.mkDefault 50;
      "vm.dirty_background_bytes" = lib.mkDefault 134217728;
      "vm.dirty_bytes" = lib.mkDefault 536870912;
      "fs.inotify.max_user_watches" = lib.mkDefault 1048576;
      "fs.inotify.max_user_instances" = lib.mkDefault 1024;
      "net.core.somaxconn" = lib.mkDefault 4096;
      "net.ipv4.ip_local_port_range" = lib.mkDefault "10240 65535";
    };
  };
}
