  { config, lib, inputs, ... }:
let
  cfg = config.features.secureboot;
in
{
  # Import upstream module here so it's only loaded when this feature is imported
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.features.secureboot = {
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
    
    # Persist keys if impermanence is active (optional integration)
    environment.persistence."/persist/system".directories = [
      cfg.pkiBundle
    ];
  };
}
