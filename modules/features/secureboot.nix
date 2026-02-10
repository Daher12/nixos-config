{ config, lib, pkgs, inputs, ... }:
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
    # Systemd-boot disablement is now handled in modules/core/boot.nix via sbActive
    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };

    environment.systemPackages = [ pkgs.sbctl ];
    
    # Persist keys automatically
    environment.persistence."/persist/system".directories = [ cfg.pkiBundle ];
  };
}
