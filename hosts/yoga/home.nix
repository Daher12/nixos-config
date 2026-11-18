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
    publicShare = "${homeDir}/public";
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
          # adb/fastboot RSA keypair (~/.android/adbkey) — the host's adb
          # setup (adbusers group + udev rule) is pointless without it:
          # unpersisted, every reboot regenerates the key and each phone
          # re-prompts "allow USB debugging?".
          {
            directory = ".android";
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
          # OnlyOffice data dir (recent-files/templates cache) next to the
          # config above — unpersisted, recents reset on root reset.
          {
            directory = ".local/share/onlyoffice";
            mode = "0700";
          }
          {
            directory = ".local/share/papers-signing";
            mode = "0700";
          }

          ".local/share/keyrings"
          ".config/mozilla/firefox"
          ".config/BraveSoftware/Brave-Browser"
          # Noctalia (niri attr, home/noctalia.nix): the GUI settings layer
          # (~/.local/state/noctalia/settings.toml — wins over the Nix
          # config.toml, which is a store symlink and needs no entry),
          # wallpaper/palette caches, installed plugins. The niri config.kdl
          # itself is an HM store symlink, re-linked every boot.
          ".local/state/noctalia"
          ".cache/noctalia"
          ".local/share/noctalia"
          # Noctalia's GTK template output: the shell gsettings-selects
          # adw-gtk3(-dark) per mode flip and writes noctalia.css + the
          # @import carrier gtk.css into the GTK config dirs
          # (home/theme.nix pins adw-gtk3 as the settings.ini fallback).
          ".config/gtk-3.0"
          ".config/gtk-4.0"
          # ZCode (Electron AppImage): auth/session + workspace state.
          ".config/ZCode"
          # ZCode auth/history lives here, not in ~/.config/ZCode
          ".zcode"
          # ZCode launcher log (home/niri.nix writes launcher.log here with
          # in-script rotation at 1 MiB) — post-mortem survives root reset.
          ".local/state/zcode"
          # Obsidian (Electron): vault registry + window state. The vault
          # itself lives in ~/Dokumente/Notes, persisted via the system-level
          # Dokumente entry in hosts/yoga/default.nix.
          ".config/obsidian"
          # Spotify (features.spotify): autologin blob + prefs live under
          # ~/.config/spotify; the client validates its session against
          # ~/.cache/spotify (storage.last-location) — wipe that and it
          # treats the device as new and asks for login despite the
          # persisted config blob.
          ".config/spotify"
          ".cache/spotify"
          # Nautilus (the file manager on the niri + GNOME attrs): view/sort preferences in
          # .config, starred files + metadata in .local/share — unpersisted,
          # both reset on every boot of the impermanence host.
          ".config/nautilus"
          ".local/share/nautilus"
          # Browser-imported certificates (NSS shared DB)
          ".pki/nssdb"
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
    xdg = {
      desktopEntries.zcode = {
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

      # obsidian:// handler for Remotely Save's OneDrive OAuth, which redirects
      # back through this scheme (remotely-save docs/linux.md + Obsidian URI
      # "Register Obsidian URI": Linux needs a real obsidian.desktop with
      # MimeType=x-scheme-handler/obsidian and Exec=... %u in a standard
      # applications dir). The mimeApps pin alone was not enough: it resolved
      # only via the per-user profile share in XDG_DATA_DIRS, left
      # ~/.local/share/applications without any obsidian.desktop, and the
      # mimeinfo.cache there was empty (update-desktop-database never ran) —
      # so Chromium/Brave, which read the desktop database, never saw the
      # handler. Note xdg.desktopEntries would NOT fix this: it installs into
      # the profile share, not the user applications dir. xdg.dataFile puts
      # the file exactly where the doc says, as a read-only store symlink
      # runtime self-registration cannot overwrite (same rationale as zcode
      # above); absolute Exec keeps portal-launched callbacks working even
      # with a minimal PATH. Built via makeDesktopItem so the entry is
      # validated at build time.
      dataFile."applications/obsidian.desktop".source =
        let
          entry = pkgs.makeDesktopItem {
            name = "obsidian";
            desktopName = "Obsidian";
            comment = "Knowledge base";
            exec = "${pkgs.obsidian}/bin/obsidian %u";
            icon = "obsidian";
            categories = [ "Office" ];
            mimeTypes = [ "x-scheme-handler/obsidian" ];
            extraConfig.StartupWMClass = "md.Obsidian";
          };
        in
        "${entry}/share/applications/obsidian.desktop";

      # Deep-link handlers folded into the HM-owned mimeapps.list, as one
      # attrset (statix: no repeated mimeApps keys; home/browsers.nix makes
      # the file a store symlink, so the runtimes' own writes of these
      # entries stop working — these pins are the declarative replacements).
      # Firefox already delegates obsidian:// to the system default
      # (handlers.json action 4 = useSystemDefault); the pin is what it
      # resolves through.
      mimeApps = {
        defaultApplications."x-scheme-handler/zcode" = [ "zcode.desktop" ];
        defaultApplications."x-scheme-handler/obsidian" = [ "obsidian.desktop" ];
        associations.added."x-scheme-handler/obsidian" = [ "obsidian.desktop" ];
      };

      userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = false;

        desktop = "$HOME/Schreibtisch";
        documents = "$HOME/Dokumente";
        download = "$HOME/Downloads";
        music = "$HOME/Musik";
        pictures = "$HOME/Bilder";
        publicShare = "$HOME/public";
        templates = "$HOME/Vorlagen";
        videos = "$HOME/Videos";
      };
    };

    # Declarative bookmarks: derived from xdg.userDirs above. Nautilus
    # bookmark edits made at runtime land in *.backup files at the next
    # activation (HM re-plants the store symlink — the declarative list
    # wins); add entries to allBookmarks here instead.
    home.file.".config/gtk-3.0/bookmarks".text = gtkBookmarksText;
    home.file.".config/gtk-4.0/bookmarks".text = gtkBookmarksText;

    # XDG publicShare points at ~/public because the persisted directory
    # must have an ASCII name (systemd rejects non-ASCII mount-unit names —
    # ~/Öffentlich never persisted, journal: "not a valid unit name"). The
    # German path keeps working as a symlink into it.
    home.file."Öffentlich".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/public";

    # Refresh the user desktop database after the obsidian.desktop entry
    # above is (re)linked: Chromium/Brave resolve protocol handlers through
    # mimeinfo.cache, not mimeapps.list, and nothing else on this system
    # regenerates it (desktop-file-utils is not in PATH otherwise).
    home.activation.obsidianDesktopDb = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.desktop-file-utils}/bin/update-desktop-database "${config.xdg.dataHome}/applications"
    '';

    browsers = {
      firefox.enable = true;
      brave.enable = true;
      # Brave >= 1.85 enables VA-API video decode on Wayland by default
      # (Chromium issue 40225939); the explicit flag is insurance against a
      # default flip regressing it. Software decode costs 3-6 W on the 680M.
      brave.extraCommandLineArgs = [ "--enable-features=VaapiVideoDecodeLinuxGL" ];
    };

    # Panel definition for EVERY session attr: battery-refresh reads it on
    # .#yoga and .#yoga-gnome alike, and home/niri.nix derives its output
    # block from it. Option lives in home/battery-refresh.nix.
    desktop.monitors = [
      {
        output = "eDP-1";
        mode = "3072x1920@120";
        position = "0x0";
        scale = "2";
      }
    ];

    # 120 -> 60 Hz on battery (~0.5-1 W at light load, the panel's EDID has
    # a native 60 Hz timing for this mode). Enforces actual-vs-desired every
    # poll, so AC transitions AND compositor-side resets (hibernate resume,
    # reload) self-heal; never while the lid is closed or (GNOME) a monitor
    # is docked.
    desktop.battery-refresh.enable = true;

    home.packages = [
      pkgs.zcode
      pkgs.obsidian
    ];
  };
}
