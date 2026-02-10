{ config, lib, pkgs, inputs, options, ... }:

let
  cfg = config.features.secureboot;
  impermanenceEnabled = config.features.impermanence.enable or false;
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

  config = lib.mkIf cfg.enable {
    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };

    environment.systemPackages = [ pkgs.sbctl ];
    
    # Only configure persistence if the feature is active
    environment.persistence."/persist/system".directories = 
      lib.mkIf (impermanenceEnabled && options ? environment.persistence) [ cfg.pkiBundle ];
  };
}
