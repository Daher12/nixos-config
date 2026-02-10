{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.features.secureboot;
in
{
  # Only import the Lanzaboote module when this feature is loaded
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.features.secureboot = {
    enable = lib.mkEnableOption "Lanzaboote Secure Boot support";
    pkiBundle = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secureboot";
      description = "Path to the PKI bundle for Secure Boot keys";
    };
  };

  config = lib.mkIf cfg.enable {
    # Lanzaboote requires systemd-boot to be disabled to avoid conflict
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };

    # Automatically provide the management tool
    environment.systemPackages = [ pkgs.sbctl ];
    
    # Automatically persist keys if persistence is active
    environment.persistence."/persist/system".directories = [
      cfg.pkiBundle
    ];
  };
}
