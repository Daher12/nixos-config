{ config, lib, pkgs, ... }:

let
  cfg = config.programs.theme;

  themeName   = "Colloid-Dark-Nord";
  themeNameLt = "Colloid-Light-Nord";
  
  colloidTheme = pkgs.unstable.colloid-gtk-theme.override { 
    tweaks = [ "nord" ]; 
  };
  
  iconTheme   = pkgs.unstable.fluent-icon-theme;
  iconName    = "Fluent-dark";
  iconNameLt  = "Fluent";

  cursorTheme = pkgs.posy-cursors;
  cursorName  = "Posy_Cursor_Black";
  cursorSize  = 32;

  switchTheme = pkgs.writeShellApplication {
    name = "switch-theme";
    runtimeInputs = with pkgs; [ dconf coreutils gnused glib ];
    text = ''
      set -euo pipefail

      MODE="''${1:-}"
      
      if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
        echo "Usage: switch-theme {dark|light}" >&2
        exit 1
      fi

      GTK3_DIR="${config.home.homeDirectory}/.config/gtk-3.0"
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

      if [[ ! -d "$THEME_BASE/$THEME/gtk-4.0" ]]; then
        echo "Error: GTK4 theme files not found in $THEME" >&2
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

      mkdir -p "$GTK3_DIR"
      cat > "$GTK3_DIR/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=$ICON
gtk-cursor-theme-name=${cursorName}
gtk-cursor-theme-size=${toString cursorSize}
gtk-application-prefer-dark-theme=$([ "$MODE" = "dark" ] && echo "1" || echo "0")
EOF

      mkdir -p "$GTK4_DIR"
      GTK4_TEMP=$(mktemp -d)
      trap 'rm -rf "$GTK4_TEMP"' EXIT

      ln -sf "$THEME_BASE/$THEME/gtk-4.0/assets" "$GTK4_TEMP/assets"
      ln -sf "$THEME_BASE/$THEME/gtk-4.0/gtk.css" "$GTK4_TEMP/gtk.css"
      
      if [ -f "$THEME_BASE/$THEME/gtk-4.0/gtk-dark.css" ]; then
        ln -sf "$THEME_BASE/$THEME/gtk-4.0/gtk-dark.css" "$GTK4_TEMP/gtk-dark.css"
      fi

      rm -f "$GTK4_DIR/gtk.css" "$GTK4_DIR/gtk-dark.css" "$GTK4_DIR/assets"
      mv "$GTK4_TEMP"/* "$GTK4_DIR/"

      if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null || true
      fi

      XRESOURCES="${config.home.homeDirectory}/.Xresources"
      if [ -f "$XRESOURCES" ]; then
        sed -i "s/^Xcursor.theme:.*/Xcursor.theme: ${cursorName}/" "$XRESOURCES" || true
        sed -i "s/^Xcursor.size:.*/Xcursor.size: ${toString cursorSize}/" "$XRESOURCES" || true
        command -v xrdb >/dev/null 2>&1 && xrdb -merge "$XRESOURCES" 2>/dev/null || true
      fi

      echo "✓ Switched to $MODE mode"
      echo "  Theme: $THEME"
      echo "  Icons: $ICON"
      echo "  Cursor: ${cursorName}"
      echo ""
      echo "Note: Some applications may require restart to fully apply changes."
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
    home.packages = with pkgs; [
      colloidTheme
      iconTheme
      cursorTheme
      switchTheme 
      libsForQt5.qt5ct
      kdePackages.qt6ct
    ];

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
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    xdg.configFile."gtk-4.0/gtk.css".enable = false;
    xdg.configFile."gtk-4.0/gtk-dark.css".enable = false;
    xdg.configFile."gtk-4.0/assets".enable = false;

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "gtk2"; 
    };

    home.pointerCursor = { 
      name = cursorName;
      package = cursorTheme; 
      size = cursorSize;
      gtk.enable = true;
      x11.enable = true; 
    };

    services.darkman = lib.mkIf cfg.autoSwitch {
      enable = true;
      settings = { 
        lat = cfg.location.latitude;
        lng = cfg.location.longitude;
        usegeoclue = false;
        portal = true;
      };
      darkModeScripts.gtk-theme  = "${switchTheme}/bin/switch-theme dark";
      lightModeScripts.gtk-theme = "${switchTheme}/bin/switch-theme light";
    };

    home.activation.applyTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${switchTheme}/bin/switch-theme dark
    '';
  };
}
