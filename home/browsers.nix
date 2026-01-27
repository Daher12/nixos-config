{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.browsers;
in
{
  options.browsers = {
    firefox = {
      enable = lib.mkEnableOption "Firefox";

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "uBlock0@raymondhill.net"
          "{446900e4-71c2-419f-a6a7-df9c091e268b}"
        ];
        description = "Firefox extension addon IDs";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Additional Firefox preferences";
      };
    };

    brave = {
      enable = lib.mkEnableOption "Brave";

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "hfmolcaikbnbminafcmeiejglbeelilh" ];
        description = "Chrome Web Store extension IDs";
      };

      extraCommandLineArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional command line arguments";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      programs.firefox = {
        enable = true;

        policies = {
          DisablePocket = true;
          DisableTelemetry = true;
          DisableFirefoxStudies = true;

          ExtensionSettings = builtins.listToAttrs (
            map (ext: {
              name = ext;
              value = {
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext}/latest.xpi";
                installation_mode = "force_installed";
              };
            }) cfg.firefox.extensions
          );
        };

        profiles.default = {
          id = 0;
          isDefault = true;

          settings = {
            "browser.startup.homepage" = "about:blank";
            "browser.search.region" = "DE";
            "intl.accept_languages" = "de-DE,de,en-US,en";
            "gfx.webrender.all" = true;
          }
          // cfg.firefox.extraSettings;
        };
      };
    })

    (lib.mkIf cfg.brave.enable {
      programs.brave = {
        enable = true;
        package = pkgs.brave;

        extensions = map (id: { inherit id; }) cfg.brave.extensions;

        commandLineArgs = lib.unique ([ "--password-store=basic" ] ++ cfg.brave.extraCommandLineArgs);
      };
    })
  ];
}
