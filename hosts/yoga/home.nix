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
          # DankMaterialShell settings: DankGreeter themes itself from
          # configHome at boot (programs.dms-greeter.configHome). Only the
          # config dir has a live reader since the DMS shell was removed
          # (2026-09-27) — the shell-owned state/state-cache dirs are gone.
          ".config/DankMaterialShell"
          # Lucid shell (home/lucid.nix): settings live INSIDE the synced
          # shell tree (~/.config/quickshell/lucidprefs/prefs.json etc.) —
          # the sync excludes exactly these from --delete. Support scripts,
          # keybinds.json and theme state under ~/.config/lucid.
          ".config/quickshell"
          ".config/lucid"
          ".cache/quickshell"
          # awww wallpaper daemon image cache — its restore-on-start source.
          # Unpersisted, every reboot came up black under a static theme
          # (2026-09-30); lucid-auto-mode repairs the image at login too,
          # this also covers mid-session daemon restarts.
          ".cache/awww"
          # Lucid's runtime-written Hyprland data: hypridle.conf (Idle
          # settings page), lucid-specials.lua, lucid-glass.lua. The HM
          # symlinks (hyprland.lua, modules/, scripts/) re-link every boot.
          ".config/hypr"
          # matugen GTK template output (colors.css + the gtk.css import
          # lucidSync appends)
          ".config/gtk-3.0"
          ".config/gtk-4.0"
          # Clipboard history (wl-paste --watch cliphist store, home/hyprland.nix)
          ".cache/cliphist"
          # ZCode (Electron AppImage): auth/session + workspace state.
          # Verify actual dirname after first launch: ls ~/.config | grep -i zcode
          ".config/ZCode"
          # ZCode auth/history lives here, not in ~/.config/ZCode
          ".zcode"
          # Obsidian (Electron): vault registry + window state. The vault
          # itself lives in ~/Dokumente/Notes, persisted via the system-level
          # Dokumente entry in hosts/yoga/default.nix.
          ".config/obsidian"
          # Nautilus (the Hyprland file manager): view/sort preferences in
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
          # set-wallpaper.sh state: active wallpaper/mode + theme name. Must
          # be FILES, not directories: lucid's shell scripts and QML FileViews
          # read/write a file at exactly these paths. Persisted as directories
          # from 2026-09-23, impermanence bind-mounted empty dirs over them
          # and every read failed "Not a file" (journal spam each shell start;
          # wallpaper/theme state markers unwritable). First switch after this
          # move needs the stale /persist-side DIRS removed (empty):
          #   sudo rmdir /persist/home/dk/.cache/current_{theme,wallpaper,mode}
          ".cache/current_theme"
          ".cache/current_wallpaper"
          ".cache/current_mode"
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
        publicShare = "$HOME/Öffentlich";
        templates = "$HOME/Vorlagen";
        videos = "$HOME/Videos";
      };
    };

    home.file.".config/gtk-3.0/bookmarks".text = gtkBookmarksText;
    home.file.".config/gtk-4.0/bookmarks".text = gtkBookmarksText;

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

    # Panel definition for BOTH sessions (also read by the GNOME-side
    # battery-refresh service on .#yoga-gnome).
    desktop.hyprland.monitors = [
      {
        output = "eDP-1";
        mode = "3072x1920@120";
        position = "0x0";
        scale = "2";
      }
    ];

    # 120 -> 60 Hz on battery (~0.5-1 W at light load, the panel's EDID has
    # a native 60 Hz timing for this mode). Triggers: AC plug/unplug, lid
    # reopen; never while the lid is closed or (GNOME) a monitor is docked.
    desktop.battery-refresh.enable = true;

    home.packages = [
      pkgs.zcode
      pkgs.obsidian
    ];

    programs = {
      fish.functions.nus = ''
        "$HOME/nixos-config/scripts/update-safe" $argv
      '';
    };
  };
}
