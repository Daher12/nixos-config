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
      coreutils
      gnused
      glib
      dbus
      systemd
    ];
    text = ''
      set -euo pipefail

      MODE="''${1:-}"

      if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
        echo "Usage: switch-theme {dark|light}" >&2
        exit 1
      fi

      XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      GTK4_DIR="$XDG_CONFIG_HOME/gtk-4.0"
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

      # GNOME / GTK: schema-aware updates (no X11 resources).
      gsettings set org.gnome.desktop.interface color-scheme "$COLOR" || true
      gsettings set org.gnome.desktop.interface gtk-theme "$THEME" || true
      gsettings set org.gnome.desktop.interface icon-theme "$ICON" || true
      gsettings set org.gnome.desktop.interface cursor-theme "${cursorName}" || true
      gsettings set org.gnome.desktop.interface cursor-size ${toString cursorSize} || true

      # GNOME Shell "user-theme" extension (ignore if not installed).
      gsettings set org.gnome.shell.extensions.user-theme name "$THEME" 2>/dev/null || true

      # Propagate for newly-launched apps (Wayland/Xwayland cursor + GTK override).
      systemctl --user set-environment \
        XCURSOR_THEME="${cursorName}" \
        XCURSOR_SIZE="${toString cursorSize}" \
        GTK_THEME="$THEME" || true

      dbus-update-activation-environment --systemd \
        XCURSOR_THEME XCURSOR_SIZE GTK_THEME 2>/dev/null || true

      # Force GTK4 theme assets (best-effort; mainly for apps reading gtk-4.0 at startup).
      mkdir -p "$GTK4_DIR"
      for item in gtk.css gtk-dark.css assets; do
        src="$THEME_BASE/$THEME/gtk-4.0/$item"
        dst="$GTK4_DIR/$item"
        [ -e "$src" ] && ln -sfn "$src" "$dst"
      done

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
        # Keep enabled to avoid regressions for the remaining Xwayland surface area.
        x11.enable = true;
      };

      activation = {
        # Prevent "file exists" when HM wants to manage (symlink) gtk-3.0/settings.ini.
        cleanupLegacyGtk3SettingsIni = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          set -eu

          SETTINGS_INI="${config.xdg.configHome}/gtk-3.0/settings.ini"

          if [ -e "$SETTINGS_INI" ] && [ ! -L "$SETTINGS_INI" ]; then
            ts="$(${pkgs.coreutils}/bin/date +%s)"
            echo "Home Manager: moving pre-existing gtk-3.0/settings.ini aside (was not a symlink)"
            ${pkgs.coreutils}/bin/mv "$SETTINGS_INI" "$SETTINGS_INI.backup.$ts"
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

    # You are managing gtk-4.0/* via the switch script (symlinks); avoid HM trying to own them.
    xdg.configFile = {
      "gtk-4.0/gtk.css".enable = false;
      "gtk-4.0/gtk-dark.css".enable = false;
      "gtk-4.0/assets".enable = false;
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "adwaita";
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
