{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.core.locale;
in
{
  options.core.locale = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      description = "System timezone";
    };

    defaultLocale = lib.mkOption {
      type = lib.types.str;
      description = "System locale";
    };

    console = {
      earlySetup = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Setup console early in boot";
      };
      font = lib.mkOption {
        type = lib.types.str;
        default = "ter-v16n";
        description = "Console font";
      };
    };
  };

  config = {
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;
    console = {
      inherit (cfg.console) earlySetup font;
      packages = [ pkgs.terminus_font ];
      useXkbConfig = true;
    };
  };
}
