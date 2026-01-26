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
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "List of Firefox extension packages";
      };
      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Extra Firefox prefs merged into the default profile (wins over defaults).";
      };
    };

    brave = {
      enable = lib.mkEnableOption "Brave";
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of Brave extension IDs";
      };
      extraCommandLineArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra Brave command line arguments appended to defaults.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      programs.firefox = {
        enable = true;
        profiles.default = {
          id = 0;
          name = "default";
          isDefault = true;
          extensions = cfg.firefox.extensions;
          settings = 
            {
              "browser.startup.homepage" = lib.mkDefault "about:blank";
              "browser.search.region" = lib.mkDefault "DE";
              "distribution.searchplugins.defaultLocale" = lib.mkDefault "de-DE";
              
              # Modern replacement for general.useragent.locale
              "intl.locale.requested" = lib.mkDefault "de-DE";
              # What websites see (HTTP Accept-Language)
              "intl.accept_languages" = lib.mkDefault "de-DE,de,en-US,en";
              
              "gfx.webrender.all" = lib.mkDefault true;
            } 
            // cfg.firefox.extraSettings;
        };
      };
    })

    (lib.mkIf cfg.brave.enable {
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        
        # Explicitly map string IDs to the submodule format required by HM
        # (Avoids relying on implicit coercion from "string" to "{ id = string; }")
        extensions = map (id: { inherit id; }) cfg.brave.extensions;

        commandLineArgs = 
          lib.unique (
            [ "--password-store=basic" ] # stable default
            ++ cfg.brave.extraCommandLineArgs
          );
      };
    })
  ];
}
