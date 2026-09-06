{
  config,
  lib,
  pkgs,
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
  imports = [
    ../../home
    ./opencode.nix
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

          ".local/share/keyrings"
          ".config/mozilla/firefox"
          ".config/BraveSoftware/Brave-Browser"
          # ZCode (Electron AppImage): auth/session + workspace state.
          # Verify actual dirname after first launch: ls ~/.config | grep -i zcode
          ".config/ZCode"
          ".local/state/wireplumber"

          ".local/share/applications"
        ];

        files = [
          ".oxrc"
          ".config/user-dirs.locale"
          ".config/monitors.xml"
        ];
      };
    };

    # ZCode rewrites ~/.local/share/applications/zcode.desktop on launch
    # (deep-link registration) to point at the raw extracted AppImage binary,
    # which only runs inside its bwrap FHS sandbox -> NixOS stub-ld failure.
    # Owning the file via xdg.desktopEntries makes it a read-only store
    # symlink the app cannot overwrite; it logs a registration error and
    # continues, while the wrapper-based Exec keeps working.
    xdg.desktopEntries.zcode = {
      type = "Application";
      name = "ZCode";
      genericName = "ZCode Desktop App";
      exec = "zcode --no-sandbox %U";
      terminal = false;
      icon = "zcode";
      settings.StartupWMClass = "ZCode";
      mimeType = [ "x-scheme-handler/zcode" ];
      categories = [ "Development" ];
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
      pkgs.zcode
    ];

    programs = {
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
