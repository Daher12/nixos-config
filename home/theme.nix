{ pkgs, ... }:

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
    runtimeInputs = with pkgs; [
      glib
      dbus
      systemd
      coreutils
    ];
    text = ''
      set -euo pipefail
      mode="''${1:-}"
      case "$mode" in
        dark)  theme="${themeDark}";  icon="${iconDark}";  color="prefer-dark" ;;
        light) theme="${themeLight}"; icon="${iconLight}"; color="prefer-light" ;;
        *) echo "usage: switch-theme {dark|light}" >&2; exit 2 ;;
      esac

      gsettings set org.gnome.desktop.interface color-scheme "$color" || true
      gsettings set org.gnome.desktop.interface gtk-theme "$theme" || true
      gsettings set org.gnome.desktop.interface icon-theme "$icon" || true
      gsettings set org.gnome.desktop.interface cursor-theme "${cursorName}" || true
      gsettings set org.gnome.desktop.interface cursor-size ${toString cursorSize} || true
      gsettings set org.gnome.shell.extensions.user-theme name "$theme" 2>/dev/null || true

      systemctl --user set-environment \
        XCURSOR_THEME="${cursorName}" \
        XCURSOR_SIZE="${toString cursorSize}" \
        GTK_THEME="$theme" || true

      dbus-update-activation-environment --systemd \
        XCURSOR_THEME XCURSOR_SIZE GTK_THEME 2>/dev/null || true
    '';
  };

  switchDark = pkgs.writeShellApplication {
    name = "switch-theme-dark";
    runtimeInputs = [ switchTheme ];
    text = "exec ${switchTheme}/bin/switch-theme dark";
  };

  switchLight = pkgs.writeShellApplication {
    name = "switch-theme-light";
    runtimeInputs = [ switchTheme ];
    text = "exec ${switchTheme}/bin/switch-theme light";
  };
in
{
  config = {
    home = {
      packages = [
        colloid
        iconPkg
        cursorPkg
        switchTheme
        switchDark
        switchLight
      ];

      # GNOME Tweaks “Shell” theme (User Themes) scans ~/.themes
      file = {
        ".themes/${themeDark}".source = "${colloid}/share/themes/${themeDark}";
        ".themes/${themeLight}".source = "${colloid}/share/themes/${themeLight}";
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = themeDark;
        package = colloid;
      };
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
