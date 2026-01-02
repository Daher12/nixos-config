{ config, pkgs, lib, ... }:

let
  # --- 1. ASSETS & NAMES ---
  themeName   = "Colloid-Dark-Nord";
  themeNameLt = "Colloid-Light-Nord";
  
  # Zugriff auf Unstable Packages via Overlay (pkgs.unstable)
  colloidTheme = pkgs.unstable.colloid-gtk-theme.override { 
    tweaks = [ "nord" ]; 
  };
  
  iconTheme   = pkgs.unstable.fluent-icon-theme;
  iconName    = "Fluent-dark";
  iconNameLt  = "Fluent";

  cursorTheme = pkgs.posy-cursors;
  cursorName  = "Posy_Cursor_Black";
  cursorSize  = 32;

  # --- 2. THE SWITCHING LOGIC (Modernized) ---
  switchTheme = pkgs.writeShellApplication {
    name = "switch-theme";
    runtimeInputs = with pkgs; [ dconf coreutils gnused ];
    text = ''
      MODE="$1"
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

      # 1. Update Dconf (The standard GNOME way)
      dconf write /org/gnome/desktop/interface/color-scheme "'$COLOR'"
      dconf write /org/gnome/desktop/interface/gtk-theme "'$THEME'"
      dconf write /org/gnome/desktop/interface/icon-theme "'$ICON'"
      dconf write /org/gnome/shell/extensions/user-theme/name "'$THEME'"

      # 2. Update GTK 4 (The manual link swap)
      mkdir -p "$GTK4_DIR"
      
      # Clean up old links safely
      rm -f "$GTK4_DIR/gtk.css" "$GTK4_DIR/gtk-dark.css" "$GTK4_DIR/assets"
      
      # Link new theme files
      ln -sf "$THEME_BASE/$THEME/gtk-4.0/assets"   "$GTK4_DIR/assets"
      ln -sf "$THEME_BASE/$THEME/gtk-4.0/gtk.css"  "$GTK4_DIR/gtk.css"
      
      # Optional: Link dark css if it exists
      if [ -f "$THEME_BASE/$THEME/gtk-4.0/gtk-dark.css" ]; then
        ln -sf "$THEME_BASE/$THEME/gtk-4.0/gtk-dark.css" "$GTK4_DIR/gtk-dark.css"
      fi

      echo "Switched to $MODE mode ($THEME)"
    '';
  };

in
{
  # --- PACKAGES ---
  home.packages = with pkgs; [
    colloidTheme
    iconTheme
    cursorTheme
    switchTheme 
    libsForQt5.qt5ct
    kdePackages.qt6ct
  ];

  # --- GTK CONFIGURATION ---
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

  # --- CRITICAL FIX: CONFLICT RESOLUTION ---
  xdg.configFile."gtk-4.0/gtk.css".enable = false;
  xdg.configFile."gtk-4.0/gtk-dark.css".enable = false;
  xdg.configFile."gtk-4.0/assets".enable = false;

  # --- QT CONFIGURATION ---
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2"; 
  };

  # --- POINTER CURSOR ---
  home.pointerCursor = { 
    name = cursorName;
    package = cursorTheme; 
    size = cursorSize;
    gtk.enable = true;
    x11.enable = true; 
  };

  # --- AUTOMATION (DARKMAN) ---
  services.darkman = {
    enable = true;
    settings = { 
      lat = 52.52; 
      lng = 13.40;
      usegeoclue = false;
      portal = true;
    };
    darkModeScripts.gtk-theme  = "${switchTheme}/bin/switch-theme dark";
    lightModeScripts.gtk-theme = "${switchTheme}/bin/switch-theme light";
  };

  # --- INITIALIZATION ---
  home.activation.applyTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${switchTheme}/bin/switch-theme dark
  '';
}
