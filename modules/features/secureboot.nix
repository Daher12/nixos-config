{ config, lib, pkgs, inputs, options, ... }:

let
  cfg = config.features.secureboot;
  # Safe check: if features.impermanence doesn't exist, default to false
  impermanenceEnabled = (config.features.impermanence or { }).enable or false;
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

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Hand-off to systemd-boot is managed by modules/core/boot.nix via sbActive check
      boot.lanzaboote = {
        enable = true;
        inherit (cfg) pkiBundle;
      };

      environment.systemPackages = [ pkgs.sbctl ];
    }

    # CRITICAL FIX: Use optionalAttrs to ensure the 'environment.persistence' key 
    # is NOT defined at all if the option doesn't exist.
    # mkIf alone is insufficient because it creates the key with a null value or assertion.
    (lib.optionalAttrs (impermanenceEnabled && options ? environment.persistence) {
      environment.persistence."/persist/system".directories = [ cfg.pkiBundle ];
    })
  ]);
}
