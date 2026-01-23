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
      "vm.swappiness" =  10;
      "vm.vfs_cache_pressure" =  50;
      "vm.dirty_background_bytes" =  134217728;
      "vm.dirty_bytes" =  536870912;
      "fs.inotify.max_user_watches" =  1048576;
      "fs.inotify.max_user_instances" =  1024;
      "net.core.somaxconn" =  4096;
      "net.ipv4.ip_local_port_range" =  "10240 65535";
    };
  };
}
