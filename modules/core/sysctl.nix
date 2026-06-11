{ config, lib, ... }:

let
  cfg = config.core.sysctl;
in
{
  options.core.sysctl = {
    optimizeForServer = lib.mkEnableOption "server-oriented sysctl defaults";
  };

  config = lib.mkMerge [
    # Universal baseline — applies regardless of server/desktop role
    {
      boot.kernel.sysctl = {
        "vm.max_map_count" = lib.mkDefault 1048576;
        "fs.file-max" = lib.mkDefault 2097152;
        "fs.inotify.max_user_watches" = lib.mkDefault 524288;
      };
    }

    # Server-oriented sysctl overrides
    (lib.mkIf cfg.optimizeForServer {
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
    })

    # Desktop defaults (ratio-based dirty writeback, suitable for workstations)
    (lib.mkIf (!cfg.optimizeForServer) {
      boot.kernel.sysctl = {
        "vm.dirty_ratio" = lib.mkDefault 10;
        "vm.dirty_background_ratio" = lib.mkDefault 5;
        "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
        "vm.dirty_expire_centisecs" = lib.mkDefault 3000;
      };
    })
  ];
}
