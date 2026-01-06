# ZRAM Swap Configuration
# vm.swappiness=100: With zram, high swappiness is optimal - prefer compressed RAM over disk
# vm.page-cluster=0: Disable readahead for swap; zram is random-access, not sequential
# vm.watermark_boost_factor=0: Disable watermark boosting; unnecessary with fast zram

{ config, lib, ... }:

let
  cfg = config.features.zram;
in
{
  options.features.zram = {
    enable = lib.mkEnableOption "ZRAM swap";

    memoryPercent = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Percentage of RAM to use for ZRAM";
    };
  };

  config = lib.mkIf cfg.enable {
    zramSwap = {
      enable = true;
      algorithm = "lz4";
      inherit (cfg) memoryPercent;
      priority = 10;
      swapDevices = 1;
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault 100;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.vfs_cache_pressure" = lib.mkDefault 100;
      "vm.page-cluster" = lib.mkDefault 0;
    };
  };
}
