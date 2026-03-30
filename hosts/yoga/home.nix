{
  lib,
  ...
}:
let
  homeDir = "/home/dk";

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
  ];

  home = {
    stateVersion = "25.11";
    sessionPath = [ "/home/dk/.local/bin" ];

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
          directory = ".config/winapps";
          mode = "0700";
        }
        {
          directory = ".config/freerdp";
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
        ".local/share/keyrings"
        ".mozilla/firefox"
        ".config/BraveSoftware/Brave-Browser"
        ".local/state/wireplumber"
        ".local/share/winapps/icons"
        ".local/share/applications"
      ];

      files = [
        ".oxrc"
        ".local/bin/windows"
        ".config/user-dirs.locale"
        ".config/monitors.xml"
      ];
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;

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

  programs.fish.functions.nus = ''
    "$HOME/nixos-config/scripts/update-safe" $argv
  '';

  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };

  programs.winapps = {
    enable = true;
    vmIP = "192.168.122.139";
    windowsDomain = "DESKTOP-DVTRQ43";
    rdpScale = 180;
  };
}
