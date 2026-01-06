{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.programs.browsers;
in
{
  options.programs.browsers = {
    firefox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Firefox";
      };
      isDefault = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Set Firefox as default browser";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "uBlock0@raymondhill.net"
          "{446900e4-71c2-419f-a6a7-df9c091e268b}"
          "@testpilot-containers"
        ];
        description = "Firefox extensions to install";
      };
      cache = {
        diskEnable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable disk cache";
        };
        memorySize = lib.mkOption {
          type = lib.types.int;
          default = 524288;
          description = "Memory cache size in KB";
        };
      };
    };
    brave = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Brave browser";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption {
                type = lib.types.str;
                description = "Chrome Web Store extension ID";
              };
            };
          }
        );
        default = [ { id = "nngceckbapebfimnlniiiahkandclblb"; } ];
        description = "Brave extensions to install";
      };
      cache = {
        path = lib.mkOption {
          type = lib.types.str;
          default = "/dev/shm/brave-cache";
          description = "Cache directory path";
        };
        size = lib.mkOption {
          type = lib.types.int;
          default = 536870912;
          description = "Cache size in bytes";
        };
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
          UserMessaging = {
            ExtensionRecommendations = false;
            SkipOnboarding = true;
          };
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
        profiles.${mainUser} = {
          inherit (cfg.firefox) isDefault;
          settings = {
            "browser.cache.disk.enable" = cfg.firefox.cache.diskEnable;
            "browser.cache.memory.enable" = true;
            "browser.cache.memory.capacity" = cfg.firefox.cache.memorySize;
            "browser.shell.checkDefaultBrowser" = false;
            "browser.ctrlTab.sortByRecentlyUsed" = true;
          };
        };
      };
    })
    (lib.mkIf cfg.brave.enable {
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        inherit (cfg.brave) extensions;
        commandLineArgs = [
          "--disk-cache-dir=${cfg.brave.cache.path}"
          "--disk-cache-size=${toString cfg.brave.cache.size}"
        ];
      };
    })
  ];
}
