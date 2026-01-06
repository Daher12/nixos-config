{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.theme;

  themeName = "Colloid-Dark-Nord";
  themeNameLt = "Colloid-Light-Nord";
  colloidTheme = pkgs.unstable.colloid-gtk-theme.override {
    tweaks = [ "nord" ];
  };

  iconTheme = pkgs.unstable.fluent-icon-theme;
  iconName = "Fluent-dark";
  iconNameLt = "Fluent";

  cursorTheme = pkgs.posy-cursors;
  cursorName = "Posy_Cursor_Black";
  cursorSize = 32;

  switchTheme = pkgs.writeShellApplication {
    name = "switch-theme";
    runtimeInputs = with pkgs; [
      dconf
      coreutils
      gnused
      glib
    ];
    text = ''
      set -euo pipefail

      MODE="''${1:-}"

      if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
        echo "Usage: switch-theme {dark|light}" >&2
        exit 1
      fi

      GTK4_DIR="${config.home.homeDirectory}/.config/gtk-4.0"
      THEME_BASE="${colloidTheme}/share/themes"

      if [ "$MODE" = "dark" ]; then
        THEME="${themeName}"
        ICON="${iconName}"
        COLOR="prefer-dark"
      else
        THEME="${themeNameLt}"
        ICON="${iconNameLt}"
        COLOR="prefer-light"
      fi

      if [[ ! -d "$THEME_BASE/$THEME" ]]; then
        echo "Error: Theme directory $THEME_BASE/$THEME not found" >&2
        exit 1
      fi

      {
        dconf write /org/gnome/desktop/interface/color-scheme "'$COLOR'"
        dconf write /org/gnome/desktop/interface/gtk-theme "'$THEME'"
        dconf write /org/gnome/desktop/interface/icon-theme "'$ICON'"
        dconf write /org/gnome/desktop/interface/cursor-theme "'${cursorName}'"
        dconf write /org/gnome/desktop/interface/cursor-size "${toString cursorSize}"
        dconf write /org/gnome/shell/extensions/user-theme/name "'$THEME'"
      } || {
        echo "Error: Failed to update dconf settings" >&2
        exit 1
      }

      mkdir -p "$GTK4_DIR"
      for item in gtk.css gtk-dark.css assets; do
        src="$THEME_BASE/$THEME/gtk-4.0/$item"
        dst="$GTK4_DIR/$item"
        [ -e "$src" ] && ln -sfn "$src" "$dst"
      done

      XRESOURCES="${config.home.homeDirectory}/.Xresources"
      if [ -f "$XRESOURCES" ]; then
        sed -i "s/^Xcursor.theme:.*/Xcursor.theme: ${cursorName}/" "$XRESOURCES" || true
        sed -i "s/^Xcursor.size:.*/Xcursor.size: ${toString cursorSize}/" "$XRESOURCES" || true
        command -v xrdb >/dev/null 2>&1 && xrdb -merge "$XRESOURCES" 2>/dev/null || true
      fi

      echo "✓ Switched to $MODE mode"
    '';
  };
in
{
  options.programs.theme = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable theme management";
    };

    autoSwitch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically switch between light/dark based on time";
    };

    location = {
      latitude = lib.mkOption {
        type = lib.types.float;
        default = 52.52;
        description = "Latitude for sunrise/sunset calculation";
      };

      longitude = lib.mkOption {
        type = lib.types.float;
        default = 13.40;
        description = "Longitude for sunrise/sunset calculation";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        colloidTheme
        iconTheme
        cursorTheme
        switchTheme
        libsForQt5.qt5ct
        kdePackages.qt6ct
      ];

      pointerCursor = {
        name = cursorName;
        package = cursorTheme;
        size = cursorSize;
        gtk.enable = true;
        x11.enable = true;
      };

      activation = {
        cleanupLegacyGtkSettings = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          SETTINGS_INI="${config.xdg.configHome}/gtk-3.0/settings.ini"
          if [ -f "$SETTINGS_INI" ] && [ ! -L "$SETTINGS_INI" ]; then
            echo "Backing up legacy mutable gtk-3.0/settings.ini to avoid conflict..."
            mv "$SETTINGS_INI" "$SETTINGS_INI.backup"
          fi
        '';

        applyTheme = lib.mkIf (!cfg.autoSwitch) (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${switchTheme}/bin/switch-theme dark
          ''
        );
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = themeName;
        package = colloidTheme;
      };
      iconTheme = {
        name = iconName;
        package = iconTheme;
      };
      cursorTheme = {
        name = cursorName;
        package = cursorTheme;
        size = cursorSize;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    };

    xdg.configFile = {
      "gtk-4.0/gtk.css".enable = false;
      "gtk-4.0/gtk-dark.css".enable = false;
      "gtk-4.0/assets".enable = false;
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "gtk2";
    };

    services.darkman = lib.mkIf cfg.autoSwitch {
      enable = true;
      settings = {
        lat = cfg.location.latitude;
        lng = cfg.location.longitude;
        usegeoclue = false;
        portal = true;
      };
      darkModeScripts.gtk-theme = "${switchTheme}/bin/switch-theme dark";
      lightModeScripts.gtk-theme = "${switchTheme}/bin/switch-theme light";
    };
  };
}
