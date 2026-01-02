{ config, lib, pkgs, ... }:

let
  cfg = config.features.kernel;
in
{
  options.features.kernel = {
    variant = lib.mkOption {
      type = lib.types.enum [ "default" "zen" "hardened" "lqx" "xanmod" ];
      default = "default";
      description = "Kernel variant";
    };

    extraParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "quiet" "splash" ];
      description = "Additional kernel command line parameters";
    };

    modules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "kvm-amd" "vfio-pci" ];
      description = "Kernel modules to load at boot";
    };

    blacklist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "nouveau" "nvidia" ];
      description = "Kernel modules to blacklist";
    };
  };

  config = {
    boot.kernelPackages = lib.mkDefault (
      if cfg.variant == "zen" then pkgs.linuxPackages_zen
      else if cfg.variant == "hardened" then pkgs.linuxPackages_hardened
      else if cfg.variant == "lqx" then pkgs.linuxPackages_lqx
      else if cfg.variant == "xanmod" then pkgs.linuxPackages_xanmod_latest
      else pkgs.linuxPackages
    );

    boot.kernelParams = cfg.extraParams;
    boot.kernelModules = cfg.modules;
    boot.blacklistedKernelModules = cfg.blacklist;
  };
}
