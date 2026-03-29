{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionals
    types
    ;
  cfg = config.features.onlyoffice;
in
{
  options.features.onlyoffice = {
    enable = mkEnableOption "ONLYOFFICE Desktop Editors";
    package = mkOption {
      type = types.package;
      default = pkgs.onlyoffice-desktopeditors;
      description = "ONLYOFFICE Desktop Editors package to install.";
    };
    installCompatibilityFonts = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install a minimal compatibility font for better substitution with
        Microsoft-oriented Office documents.
      '';
    };
    enableSharedFonts = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Nudge the shared repo font feature on with mkDefault. When disabled,
        this module stays silent and does not contribute any definition to
        features.fonts.enable.
      '';
    };
  };
  config = mkIf cfg.enable {
    features.fonts.enable = mkIf cfg.enableSharedFonts (mkDefault true);
    environment.systemPackages = [
      cfg.package
    ];
    fonts.packages = optionals cfg.installCompatibilityFonts [
      pkgs.liberation_ttf
    ];
  };
}
