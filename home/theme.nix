{ config, lib, pkgs, ... }:

let
  themeDark = "Colloid-Dark-Nord";
  themeLight = "Colloid-Light-Nord";

  colloid = pkgs.unstable.colloid-gtk-theme.override { tweaks = [ "nord" ]; };

  iconPkg = pkgs.unstable.fluent-icon-theme;
  iconDark = "Fluent-dark";
  iconLight = "Fluent";

  cursorPkg = pkgs.posy-cursors;
  cursorName = "Posy_Cursor_Black";
  cursorSize = 32;

  switchTheme = pkgs.writeShellApplication {
    name = "switch-theme";
    runtimeInputs = with pkgs; [ coreutils glib dbus systemd ];
    text = ''
      set -euo pipefail

      mode="''${1:-}"
      case "$mode" in
        dark)
          theme="${themeDark}"
          icon="${iconDark}"
          color="prefer-dark"
          ;;
        light)
          theme="${themeLight}"
          icon="${iconLight}"
          color="prefer-light"
          ;;
        *)
          echo "usage: switch-theme {dark|light}" >&2
          exit 2
          ;;
      esac

      # GNOME / GTK settings
      gsettings set org.gnome.desktop.interface color-scheme "$color" || true
      gsettings set org.gnome.desktop.interface gtk-theme "$theme" || true
      gsettings set org.gnome.desktop.interface icon-theme "$icon" || true
      gsettings set org.gnome.desktop.interface cursor-theme "${cursorName}" || true
      gsettings set org.gnome.desktop.interface cursor-size ${toString cursorSize} || true

      # GNOME Tweaks → Appearance → Shell (User Themes extension)
      gsettings set org.gnome.shell.extensions.user-theme name "$theme" 2>/dev/null || true

      # Ensure newly launched apps inherit overrides
      systemctl --user set-environment \
        XCURSOR_THEME="${cursorName}" \
        XCURSOR_SIZE="${toString cursorSize}" \
        GTK_THEME="$theme" || true

      dbus-update-activation-environment --systemd \
        XCURSOR_THEME XCURSOR_SIZE GTK_THEME 2>/dev/null || true

      # Model A: runtime owns ~/.config/gtk-4.0/*
      XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      GTK4_DIR="$XDG_CONFIG_HOME/gtk-4.0"
      THEME_BASE="${colloid}/share/themes"

      mkdir -p "$GTK4_DIR"
      for item in gtk.css gtk-dark.css assets; do
        src="$THEME_BASE/$theme/gtk-4.0/$item"
        dst="$GTK4_DIR/$item"
        if [ -e "$src" ]; then
          ln -sfn "$src" "$dst"
        fi
      done
    '';
  };

  # darkman expects executable paths (no arguments)
  switchDark = pkgs.writeShellApplication {
    name = "switch-theme-dark";
    runtimeInputs = [ switchTheme ];
    text = ''exec ${switchTheme}/bin/switch-theme dark'';
  };

  switchLight = pkgs.writeShellApplication {
    name = "switch-theme-light";
    runtimeInputs = [ switchTheme ];
    text = ''exec ${switchTheme}/bin/switch-theme light'';
  };
in
{
  config = {
    # Ensure HM does not try to own these GTK4 override paths (runtime does).
    xdg.configFile = {
      "gtk-4.0/gtk.css".enable = lib.mkForce false;
      "gtk-4.0/gtk-dark.css".enable = lib.mkForce false;
      "gtk-4.0/assets".enable = lib.mkForce false;
    };

    home = {
      packages = [
        colloid
        iconPkg
        cursorPkg
        switchTheme
        switchDark
        switchLight
      ];

      # Make themes discoverable to User Themes (GNOME Shell scans ~/.themes)
      file = {
        ".themes/${themeDark}".source = "${colloid}/share/themes/${themeDark}";
        ".themes/${themeLight}".source = "${colloid}/share/themes/${themeLight}";
      };

      pointerCursor = {
        name = cursorName;
        package = cursorPkg;
        size = cursorSize;
        gtk.enable = true;
        x11.enable = true;
      };
    };

    gtk = {
      enable = true;
      theme = { name = themeDark; package = colloid; };
      iconTheme = { name = iconDark; package = iconPkg; };
      cursorTheme = { name = cursorName; package = cursorPkg; size = cursorSize; };
    };

    services.darkman = {
      enable = true;
      settings = {
        portal = true;
        lat = 52.52;
        lng = 13.40;
        usegeoclue = false;
      };
      darkModeScripts.gtk-theme = "${switchDark}/bin/switch-theme-dark";
      lightModeScripts.gtk-theme = "${switchLight}/bin/switch-theme-light";
    };
  };
}

