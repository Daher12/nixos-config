{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  homeDir = config.home.homeDirectory;

  xdgDirs = {
    desktop = "${homeDir}/Schreibtisch";
    documents = "${homeDir}/Dokumente";
    download = "${homeDir}/Downloads";
    music = "${homeDir}/Musik";
    pictures = "${homeDir}/Bilder";
    publicShare = "${homeDir}/Öffentlich";
    templates = "${homeDir}/Vorlagen";
    videos = "${homeDir}/Videos";
  };

  extraBookmarks = [
    {
      path = "/mnt/nas";
      label = "NAS";
    }
  ];

  xdgBookmarks = [
    {
      path = xdgDirs.documents;
      label = "Dokumente";
    }
    {
      path = xdgDirs.download;
      label = "Downloads";
    }
    {
      path = xdgDirs.music;
      label = "Musik";
    }
    {
      path = xdgDirs.pictures;
      label = "Bilder";
    }
    {
      path = xdgDirs.videos;
      label = "Videos";
    }
    {
      path = "${homeDir}/nixos-config";
      label = "nixos-config";
    }
  ];

  allBookmarks = xdgBookmarks ++ extraBookmarks;

  mkGtkBookmarkLine =
    bookmark:
    let
      escapedPath = lib.replaceStrings [ " " ] [ "%20" ] bookmark.path;
    in
    "file://${escapedPath} ${bookmark.label}";

  gtkBookmarksText = lib.concatStringsSep "\n" (map mkGtkBookmarkLine allBookmarks) + "\n";
in
{
  options.custom.mikrotikMcp.enable = lib.mkEnableOption "MikroTik MCP server (mikromcp)";

  imports = [
    ../../home
  ];

  config = {
    home = {
      stateVersion = "25.11";
      sessionPath = [ "${homeDir}/.local/bin" ];

      persistence."/persist" = {
        directories = [
          {
            directory = ".ssh";
            mode = "0700";
          }
          {
            directory = ".gnupg";
            mode = "0700";
          }
          {
            directory = ".config/sops/age";
            mode = "0700";
          }
          {
            directory = ".config/fish";
            mode = "0700";
          }
          {
            directory = ".config/dconf";
            mode = "0700";
          }

          {
            directory = ".local/share/fish";
            mode = "0700";
          }
          {
            directory = ".config/onlyoffice";
            mode = "0700";
          }
          {
            directory = ".local/share/papers-signing";
            mode = "0700";
          }
          {
            directory = ".local/share/opencode";
            mode = "0700";
          }
          {
            directory = ".local/state/opencode";
            mode = "0700";
          }
          {
            directory = ".cache/opencode";
            mode = "0700";
          }
          {
            directory = ".config/opencode";
            mode = "0700";
          }

          ".local/share/keyrings"
          ".config/mozilla/firefox"
          ".config/BraveSoftware/Brave-Browser"
          ".local/state/wireplumber"
          ".local/share/applications"
          {
            directory = ".mikromcp";
            mode = "0700";
          }
        ];

        files = [
          ".oxrc"
          ".config/user-dirs.locale"
          ".config/monitors.xml"
        ];
      };
    };

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = false;

      desktop = "$HOME/Schreibtisch";
      documents = "$HOME/Dokumente";
      download = "$HOME/Downloads";
      music = "$HOME/Musik";
      pictures = "$HOME/Bilder";
      publicShare = "$HOME/Öffentlich";
      templates = "$HOME/Vorlagen";
      videos = "$HOME/Videos";
    };

    home.file.".config/gtk-3.0/bookmarks".text = gtkBookmarksText;
    home.file.".config/gtk-4.0/bookmarks".text = gtkBookmarksText;

    browsers = {
      firefox.enable = true;
      brave.enable = true;
    };

    home.packages = [
      pkgs.jan
      pkgs.mcp-nixos
    ];

    # NOTE: opencode-cache-clean service REMOVED — was deleting node_modules
    # on boot, potentially breaking provider initialization. OpenCode manages
    # its own cache; deleting it forces re-download which can fail or race.

    programs = {
      opencode = {
        enable = true;
        package = inputs.opencode.packages.x86_64-linux.default.overrideAttrs (previousAttrs: {
          postFixup = (previousAttrs.postFixup or "") + ''
            wrapProgram $out/bin/opencode \
              --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
          '';
        });
        settings = {
          model = "openrouter/deepseek/deepseek-v4-flash";
          small_model = "openrouter/mistralai/mistral-small-3.2-24b-instruct";
          provider = {
            openrouter = {
              models = {
                "deepseek/deepseek-v4-flash" = { };
                "deepseek/deepseek-v4-pro" = {
                  options = {
                    provider = {
                      order = [ "deepseek" ];
                      allow_fallbacks = true;
                    };
                  };
                };
              };
            };
            orcarouter = {
              npm = "@ai-sdk/openai-compatible";
              name = "OrcaRouter";
              options = {
                baseURL = "https://api.orcarouter.ai/v1";
                apiKey = "{env:ORCAROUTER_API_KEY}";
              };
              models = {
                "orcarouter/auto" = {
                  name = "OrcaRouter Auto";
                };
              };
            };
          };
          permission = {
            edit = "ask";
            bash = {
              "*" = "ask";
              "git status" = "allow";
              "git diff *" = "allow";
              "rm -rf *" = "deny";
            };
          };
          mcp = {
            nixos = {
              type = "local";
              command = [ "mcp-nixos" ];
            };
          }
          // lib.optionalAttrs config.custom.mikrotikMcp.enable {
            mikrotik = {
              type = "local";
              # Fixed nix package (pkgs/mikromcp.nix) — no npx/network at runtime.
              # Toggle via `hosts/yoga/default.nix:25` (custom.mikrotikMcp.enable).
              command = [
                "${lib.getExe pkgs.mikromcp}"
                "serve"
              ];
            };
          };
        };
      };

      fish.functions.nus = ''
        "$HOME/nixos-config/scripts/update-safe" $argv
      '';

      fish.interactiveShellInit = ''
        if test -f /run/secrets/orcarouter_api_key
          set -gx ORCAROUTER_API_KEY (cat /run/secrets/orcarouter_api_key)
        end
      '';
    };
  };
}
