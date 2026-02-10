{ config, lib, pkgs, inputs, options, ... }:

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
    (lib.mkIf cfg.enable {
      # Hand-off to systemd-boot is managed by modules/core/boot.nix via sbActive check
      boot.lanzaboote = {
        enable = true;
        inherit (cfg) pkiBundle;
      };

      environment.systemPackages = [ pkgs.sbctl ];
    })

    # Guard persistence config: Use optionalAttrs so the 'environment.persistence'
    # key is not even defined if the option doesn't exist.
    (lib.mkIf cfg.enable (lib.optionalAttrs (options ? environment.persistence) {
      environment.persistence."/persist/system".directories = [ cfg.pkiBundle ];
    }))
  ];
}
