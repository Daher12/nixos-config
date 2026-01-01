{ config, lib, pkgs, ... }:

let
  cfg = config.features.kernel;
in
{
  options.features.kernel = {
    variant = lib.mkOption {
      type = lib.types.enum [ "default" "zen" "hardened" ];
      default = "default";
      description = "Kernel variant to use";
    };

    extraParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional kernel parameters";
    };
  };

  config = {
    boot.kernelPackages = lib.mkDefault (
      if cfg.variant == "zen" then pkgs.linuxPackages_zen
      else if cfg.variant == "hardened" then pkgs.linuxPackages_hardened
      else pkgs.linuxPackages
    );

    boot.kernelParams = cfg.extraParams;
  };
}
