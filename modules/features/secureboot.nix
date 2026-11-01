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
      description = "Path to the sbctl PKI bundle holding the UEFI secure-boot keys";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sbctl ];

    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };

    environment.persistence = lib.mkIf config.features.impermanence.enable {
      "/persist/system".directories = [ cfg.pkiBundle ];
    };
  };
}
