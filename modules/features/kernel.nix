{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.kernel;
  kernelPackages = {
    default = pkgs.linuxPackages;
    latest = pkgs.linuxPackages_latest;
    zen = pkgs.linuxPackages_zen;
    hardened = pkgs.linuxPackages_hardened;
    lqx = pkgs.linuxPackages_lqx;
    xanmod = pkgs.linuxPackages_xanmod_latest;
  };
in
{
  options.features.kernel = {
    enable = lib.mkEnableOption "custom kernel variant and parameters";

    variant = lib.mkOption {
      type = lib.types.enum [
        "default"
        "latest"
        "zen"
        "hardened"
        "lqx"
        "xanmod"
      ];
      default = "default";
      description = "Kernel variant";
    };

    extraParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "quiet"
        "splash"
      ];
      description = "Additional kernel command line parameters";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelPackages = lib.mkDefault kernelPackages.${cfg.variant};
      kernelParams = lib.mkBefore cfg.extraParams;

      kernel.sysctl = lib.mkIf (cfg.variant == "zen") {
        # 0 = the long-running EFFECTIVE value: system76-scheduler forced
        # autogroup off fleet-wide until its removal (2026-11-25 perf round).
        # Pinning 0 keeps behavior identical after that removal; the kernel
        # default would be 1.
        "kernel.sched_autogroup_enabled" = 0;
      };
    };
  };
}
