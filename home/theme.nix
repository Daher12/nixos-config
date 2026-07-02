{
  lib,
  pkgs,
  ...
}:

let
  activeTheme = "mactahoe"; # "colloid" or "mactahoe"

  themePkg =
    if activeTheme == "mactahoe" then pkgs.mactahoe-gtk-theme
    else pkgs.colloid-gtk-theme.override { tweaks = [ "nord" ]; };

  themeDark = if activeTheme == "mactahoe" then "MacTahoe-Dark-nord"
              else "Colloid-Dark-Nord";
  themeLight = if activeTheme == "mactahoe" then "MacTahoe-Light-nord"
               else "Colloid-Light-Nord";

  iconPkg = pkgs.fluent-icon-theme;
  iconDark = "Fluent-dark";
  iconLight = "Fluent";

  cursorPkg = pkgs.posy-cursors;
  cursorName = "Posy_Cursor_Black";
  cursorSize = 32;

  switchTheme = pkgs.writeShellApplication {
    name = "switch-theme";
    runtimeInputs = with pkgs; [
      glib
      dbus
      systemd
      dconf
    ];
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

      gsettings set org.gnome.desktop.interface color-scheme "$color" || true
      gsettings set org.gnome.desktop.interface gtk-theme "$theme" || true
      gsettings set org.gnome.desktop.interface icon-theme "$icon" || true

      dconf write /org/gnome/shell/extensions/user-theme/name "'$theme'" || true

      systemctl --user set-environment GTK_THEME="$theme" || true

      dbus-update-activation-environment --systemd GTK_THEME 2>/dev/null || true

      # Runtime owns ~/.config/gtk-4.0/*
      XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      GTK4_DIR="$XDG_CONFIG_HOME/gtk-4.0"
      THEME_BASE="${themePkg}/share/themes"

      mkdir -p "$GTK4_DIR"
      for item in gtk.css gtk-dark.css assets; do
        src="$THEME_BASE/$theme/gtk-4.0/$item"
        dst="$GTK4_DIR/$item"
        [ -e "$src" ] || continue
        [ ! -L "$dst" ] && [ -d "$dst" ] && mv "$dst" "$dst.rm" && rm -rf "$dst.rm"
        ln -sfn "$src" "$dst"
      done
    '';
  };

  switchDark = pkgs.writeShellApplication {
    name = "switch-theme-dark";
    runtimeInputs = [ ];
    text = "exec ${switchTheme}/bin/switch-theme dark";
  };

  switchLight = pkgs.writeShellApplication {
    name = "switch-theme-light";
    runtimeInputs = [ ];
    text = "exec ${switchTheme}/bin/switch-theme light";
  };
in
{
  config = {
    # Cursor and session environment — set once at login, not per mode-switch.
    dconf.settings."org/gnome/desktop/interface" = {
      cursor-theme = cursorName;
      cursor-size = cursorSize;
    };

    home.sessionVariables = {
      XCURSOR_THEME = cursorName;
      XCURSOR_SIZE = toString cursorSize;
    };

    systemd.user.sessionVariables = {
      XCURSOR_THEME = cursorName;
      XCURSOR_SIZE = toString cursorSize;
    };

    # Prevent HM from trying to own these (your script owns them).
    xdg.configFile = {
      "gtk-4.0/gtk.css".enable = lib.mkForce false;
      "gtk-4.0/gtk-dark.css".enable = lib.mkForce false;
      "gtk-4.0/assets".enable = lib.mkForce false;
    };

    home = {
      packages = [
        themePkg
        iconPkg
        cursorPkg
        switchTheme
        switchDark
        switchLight
      ];

      # Required for GNOME Shell theme discovery by User Themes: expose in ~/.themes
      file = {
        ".themes/${themeDark}".source = "${themePkg}/share/themes/${themeDark}";
        ".themes/${themeLight}".source = "${themePkg}/share/themes/${themeLight}";
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = themeDark;
        package = themePkg;
      };
      gtk4.theme = null;
      iconTheme = {
        name = iconDark;
        package = iconPkg;
      };
      cursorTheme = {
        name = cursorName;
        package = cursorPkg;
        size = cursorSize;
      };
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
