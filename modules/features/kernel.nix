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
    enable = lib.mkEnableOption "custom kernel variant and parameters" // {
      default = true;
    };

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
        "kernel.sched_autogroup_enabled" = 1;
      };
    };
  };
}
