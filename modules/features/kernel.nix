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
    zen = pkgs.linuxPackages_zen;
    hardened = pkgs.linuxPackages_hardened;
    lqx = pkgs.linuxPackages_lqx;
    xanmod = pkgs.linuxPackages_xanmod_latest;
  };
in
{
  options.features.kernel = {
    variant = lib.mkOption {
      type = lib.types.enum [
        "default"
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

  config = {
    boot.kernelPackages = lib.mkDefault kernelPackages.${cfg.variant};
    boot.kernelParams = lib.mkBefore cfg.extraParams;
    
    boot.kernel.sysctl = lib.mkIf (cfg.variant == "zen") {
      "kernel.sched_autogroup_enabled" = 1;
    };
  };
}
