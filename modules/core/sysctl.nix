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
      "vm.swappiness" = lib.mkForce 10;
      "vm.vfs_cache_pressure" = lib.mkForce 50;
      "vm.dirty_background_bytes" = lib.mkForce 134217728;
      "vm.dirty_bytes" = lib.mkForce 536870912;
      "fs.inotify.max_user_watches" = lib.mkForce 1048576;
      "fs.inotify.max_user_instances" = lib.mkForce 1024;
      "net.core.somaxconn" = lib.mkForce 4096;
      "net.ipv4.ip_local_port_range" = lib.mkForce "10240 65535";
    };
  };
}
