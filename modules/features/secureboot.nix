{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.features.secureboot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.features.secureboot = {
    enable = lib.mkEnableOption "Lanzaboote Secure Boot support";

    pkiBundle = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sbctl";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (config.features.impermanence.enable or false) {
      environment.persistence."/persist/system".directories = [ cfg.pkiBundle ];
    })

    (lib.mkIf ((config.features.impermanence.enable or false) || cfg.enable) {
      environment.systemPackages = [ pkgs.sbctl ];
    })

    (lib.mkIf cfg.enable {
      boot.loader.systemd-boot.enable = lib.mkForce false;

      boot.lanzaboote = {
        enable = true;
        inherit (cfg) pkiBundle;
      };
    })
  ];
}
