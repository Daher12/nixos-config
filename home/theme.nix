{
  lib,
  pkgs,
  ...
}:

let
  themeDark = "Colloid-Dark-Nord";
  themeLight = "Colloid-Light-Nord";

  colloid = pkgs.colloid-gtk-theme.override { tweaks = [ "nord" ]; };

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

      # GNOME interface keys: gsettings (schema-aware)
      gsettings set org.gnome.desktop.interface color-scheme "$color" || true
      gsettings set org.gnome.desktop.interface gtk-theme "$theme" || true
      gsettings set org.gnome.desktop.interface icon-theme "$icon" || true
      gsettings set org.gnome.desktop.interface cursor-theme "${cursorName}" || true
      gsettings set org.gnome.desktop.interface cursor-size ${toString cursorSize} || true

      # GNOME Tweaks → Appearance → Shell (User Themes extension):
      # Use dconf to avoid schema/path visibility issues.
      dconf write /org/gnome/shell/extensions/user-theme/name "'$theme'" || true

      # Ensure newly launched apps inherit overrides
      systemctl --user set-environment \
        XCURSOR_THEME="${cursorName}" \
        XCURSOR_SIZE="${toString cursorSize}" \
        GTK_THEME="$theme" || true

      dbus-update-activation-environment --systemd \
        XCURSOR_THEME XCURSOR_SIZE GTK_THEME 2>/dev/null || true

      # Runtime owns ~/.config/gtk-4.0/*
      XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      GTK4_DIR="$XDG_CONFIG_HOME/gtk-4.0"
      THEME_BASE="${colloid}/share/themes"

      mkdir -p "$GTK4_DIR"
      for item in gtk.css gtk-dark.css assets; do
        src="$THEME_BASE/$theme/gtk-4.0/$item"
        dst="$GTK4_DIR/$item"
        [ -e "$src" ] || continue
        [ ! -L "$dst" ] && [ -d "$dst" ] && rm -rf "$dst"
        ln -sfn "$src" "$dst"
      done
    '';
  };

  switchDark = pkgs.writeShellScriptBin "switch-theme-dark" ''
    exec ${switchTheme}/bin/switch-theme dark
  '';

  switchLight = pkgs.writeShellScriptBin "switch-theme-light" ''
    exec ${switchTheme}/bin/switch-theme light
  '';
in
{
  config = {
    # Prevent HM from trying to own these (your script owns them).
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

      # Required for GNOME Shell theme discovery by User Themes: expose in ~/.themes
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
