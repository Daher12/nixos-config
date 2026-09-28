{
  lib,
  pkgs,
  config,
  ...
}:

let
  # Single source for the light/dark theme + icon names: declared as options
  # above so home/lucid.nix (auto light/dark wrapper) reads the same values
  # instead of mirroring plain let-bindings with a "keep in sync" comment.
  inherit (config.desktop.theme)
    gtkDark
    gtkLight
    iconDark
    iconLight
    ;

  colloid = pkgs.colloid-gtk-theme.override { tweaks = [ "nord" ]; };

  iconPkg = pkgs.fluent-icon-theme;

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
          theme="${gtkDark}"
          icon="${iconDark}"
          color="prefer-dark"
          ;;
        light)
          theme="${gtkLight}"
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
      THEME_BASE="${colloid}/share/themes"

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
  # Single source for the light/dark GTK + icon theme names (home/lucid.nix's
  # auto light/dark wrapper reads these instead of mirroring let-bindings).
  options.desktop.theme = {
    gtkDark = lib.mkOption {
      type = lib.types.str;
      default = "Colloid-Dark-Nord";
      description = "GTK theme name for dark mode";
    };
    gtkLight = lib.mkOption {
      type = lib.types.str;
      default = "Colloid-Light-Nord";
      description = "GTK theme name for light mode";
    };
    iconDark = lib.mkOption {
      type = lib.types.str;
      default = "Fluent-dark";
      description = "Icon theme name for dark mode";
    };
    iconLight = lib.mkOption {
      type = lib.types.str;
      default = "Fluent";
      description = "Icon theme name for light mode";
    };
  };

  config = {
    # Cursor and session environment — set once at login, not per mode-switch.
    # NOTE: modules/features/onlyoffice.nix may override XCURSOR_SIZE at the
    # NixOS level (environment.sessionVariables) when setGlobalCursorSize=true.
    # That takes precedence over these HM-level variables for affected hosts.
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
        colloid
        iconPkg
        cursorPkg
        switchTheme
        switchDark
        switchLight
      ];

      # Required for GNOME Shell theme discovery by User Themes: expose in ~/.themes
      file = {
        ".themes/${gtkDark}".source = "${colloid}/share/themes/${gtkDark}";
        ".themes/${gtkLight}".source = "${colloid}/share/themes/${gtkLight}";
      };
    };

    # HM's gtk module would own ~/.config/gtk-{3.0,4.0}/settings.ini, but
    # Lucid's envtool rewrites those files at every shell start (atomic
    # rename — replaces the HM store symlink with a real file). The stale
    # .backup HM keeps then aborts the next boot-time activation entirely
    # (2026-09-24: no lucid.service, default cursor). Lucid owns the ini
    # files on its host (dconf above covers the gsettings side); hosts
    # without the shell keep the declarative HM theme.
    gtk = {
      enable = !config.desktop.lucid.enable;
      theme = {
        name = gtkDark;
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

    # darkman day/night GTK switching — disabled on the Hyprland attr, where
    # DMS matugen dynamic theming owns GTK (features.desktop-hyprland).
    # Running both would fight over ~/.config/gtk-4.0 and GTK_THEME.
    services.darkman = lib.mkIf (!config.desktop.hyprland.enable) {
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
