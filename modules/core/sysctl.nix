{ config, lib, ... }:

let
  cfg = config.core.sysctl;
in
{
  options.core.sysctl = {
    optimizeForServer = lib.mkEnableOption "server-oriented sysctl defaults";
  };

  config =
    let
      serverSysctl = {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_background_bytes" = 134217728;
        "vm.dirty_bytes" = 536870912;
        "fs.inotify.max_user_watches" = 1048576;
        "fs.inotify.max_user_instances" = 1024;
        "net.core.somaxconn" = 4096;
        "net.ipv4.ip_local_port_range" = "10240 65535";
      };
      desktopSysctl = {
        "vm.dirty_ratio" = lib.mkDefault 10;
        "vm.dirty_background_ratio" = lib.mkDefault 5;
        "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
        "vm.dirty_expire_centisecs" = lib.mkDefault 3000;
      };
    in
    {
      boot.kernel.sysctl = {
        "fs.file-max" = lib.mkDefault 2097152;
      }
      // (if cfg.optimizeForServer then serverSysctl else desktopSysctl);
    };
}
