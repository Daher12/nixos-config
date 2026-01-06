{ config, lib, ... }:

let
  cfg = config.core.secureboot;
in
{
  options.core.secureboot = {
    enable = lib.mkEnableOption "Secure Boot using Lanzaboote";

    pkiBundle = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sbctl";
      description = "Path to the PKI bundle for Secure Boot keys";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.lanzaboote = {
      enable = true;
      inherit (cfg) pkiBundle;
    };
  };
}
