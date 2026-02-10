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
      default = "/etc/secureboot";
    };
  };

  config = lib.mkIf cfg.enable {
    # Hand-off to systemd-boot is managed by modules/core/boot.nix via sbActive check
    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };

    environment.systemPackages = [ pkgs.sbctl ];
    
    # Guard persistence config to prevent evaluation errors on non-impermanent hosts
    environment.persistence."/persist/system".directories = 
      lib.mkIf (options ? environment.persistence) [ cfg.pkiBundle ];
  };
}
