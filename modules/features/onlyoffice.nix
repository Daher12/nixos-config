{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.onlyoffice;
in
{
  options.features.onlyoffice = {
    enable = lib.mkEnableOption "ONLYOFFICE Desktop Editors";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.onlyoffice-desktopeditors;
      description = "ONLYOFFICE Desktop Editors package to install.";
    };

    installCompatibilityFonts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install a minimal compatibility font for better substitution with
        Microsoft-oriented Office documents.
      '';
    };

    enableSharedFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Nudge the shared repo font feature on with mkDefault. When disabled,
        this module stays silent and does not contribute any definition to
        features.fonts.enable.
      '';
    };

    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 64;
      description = "Cursor size to export when ONLYOFFICE is enabled.";
    };

    setGlobalCursorSize = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Export XCURSOR_SIZE globally when ONLYOFFICE is enabled so the stock
        desktop launcher also inherits the larger cursor size.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    features.fonts.enable = lib.mkIf cfg.enableSharedFonts (lib.mkDefault true);

    environment.systemPackages = [
      cfg.package
    ];

    fonts.packages = lib.optionals cfg.installCompatibilityFonts [
      pkgs.liberation_ttf
    ];

    environment.sessionVariables = lib.mkIf cfg.setGlobalCursorSize {
      XCURSOR_SIZE = toString cfg.cursorSize;
    };
  };
}
