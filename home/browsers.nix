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
    firefox.enable = lib.mkEnableOption "Firefox with uBlock Origin and Bitwarden";
    brave.enable = lib.mkEnableOption "Brave with Bitwarden";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      programs.firefox = {
        enable = true;

        policies = {
          DisablePocket = true;
          DisableTelemetry = true;
          DisableFirefoxStudies = true;

          ExtensionSettings = {
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "force_installed";
            };
            "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
              installation_mode = "force_installed";
            };
          };
        };

        profiles.default = {
          id = 0;
          isDefault = true;
          settings = {
            "browser.startup.homepage" = "about:blank";
            "gfx.webrender.all" = true;
          };
        };
      };
    })

    (lib.mkIf cfg.brave.enable {
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        extensions = [{ id = "nngceckbapebfimnlniiiahkandclblb"; }]; # Bitwarden
        commandLineArgs = [ "--password-store=basic" ];
      };

      # Brave ships multiple .desktop variants - hide extras
      xdg.desktopEntries = {
        "brave-browser-beta".noDisplay = true;
        "brave-browser-nightly".noDisplay = true;
        "brave-browser-dev".noDisplay = true;
      };
    })
  ];
}
