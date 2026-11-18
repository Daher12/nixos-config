{
  lib,
  pkgs,
  config,
  ...
}:

let
  # Light/dark theme + icon names come from the desktop.theme options below —
  # single source (see that block for the libadwaita caveat).
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
  # Single source for the light/dark GTK + icon theme names.
  # NOTE (updated 2026-11-18): on the noctalia attr these names are inert
  # fallbacks — day/night theming is Noctalia's job (home/noctalia.nix):
  # its gtk3/gtk4 templates regenerate ~/.config/gtk-{3,4}.0/noctalia.css
  # from the wallpaper-M3 palette at every mode flip and inject an @import
  # into gtk.css; user-priority named colors recolor libadwaita apps too
  # (which otherwise ignore gtk-theme-name BY DESIGN and only follow
  # gsettings color-scheme). On non-noctalia hosts the switch-theme script
  # below swaps these names via gsettings + the gtk-4.0 symlink farm.
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
      # The installed light variant name: the bare "Fluent" default drifted
      # from the value gsettings/prefs actually carried (live-verified
      # 2026-10-13: Fluent-light).
      default = "Fluent-light";
      description = "Icon theme name for light mode";
    };
  };

  config = {
    # Cursor and session environment — set once at login, not per mode-switch.
    # NOTE: /etc/profile (environment.sessionVariables) sources after
    # home.sessionVariables, so any entry there for these vars would beat
    # the values chosen here at boot (that is why ONLYOFFICE's bigger
    # cursor is scoped to its own .desktop wrap,
    # modules/features/onlyoffice.nix).
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

    # (The old xdg.configFile mkForce-false entries for gtk-4.0/gtk.css,
    # gtk-dark.css and assets were dead weight: gtk4.theme = null below
    # already prevents HM from generating those files, and a disabled
    # xdg.configFile entry contributes nothing either way. Removed
    # 2026-11-18 audit — the home-files diff proof guards the removal.)

    home = {
      packages = [
        colloid
        iconPkg
        # cursorPkg deliberately NOT listed here: gtk.cursorTheme.package
        # (below) already installs it into the profile — the extra entry
        # was a double install (audit 2026-11-18).
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

    # HM owns ~/.config/gtk-{3,4}.0/settings.ini on every attr. The
    # noctalia shell paints through its own noctalia.css + gsettings and
    # does NOT atomically rewrite the HM-owned ini files (unlike the
    # retired lucid envtool, whose rewrites + stale .backup aborted whole
    # activations — 2026-09-24).
    gtk = {
      # Noctalia hosts: the shell's gtk3/gtk4 templates swap gsettings
      # gtk-theme between adw-gtk3 (light) and adw-gtk3-dark on every mode
      # flip and paint the palette through
      # ~/.config/gtk-{3,4}.0/noctalia.css (adw-gtk3 lives in
      # desktop-niri.nix systemPackages so the template's theme lookup
      # succeeds). settings.ini is only the pre-first-apply fallback — pin
      # the light face so a fallback boot still matches daytime; a Colloid
      # pin here would win for GTK3 apps reading settings.ini and keep
      # them off-palette.
      enable = true;
      theme = {
        name = if config.desktop.noctalia.enable then "adw-gtk3" else gtkDark;
        package = if config.desktop.noctalia.enable then pkgs.adw-gtk3 else colloid;
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

    # darkman day/night GTK switching — disabled on the noctalia attr:
    # day/night is Noctalia's job there (theme.mode = "auto" +
    # templates gtk3/gtk4, home/noctalia.nix), and running both would
    # fight over ~/.config/gtk-4.0 and GTK_THEME. (On the GNOME hosts
    # darkman is the day/night switcher.) Coordinates = darkman parity
    # with Noctalia's [location] (home/noctalia.nix).
    services.darkman = lib.mkIf (!config.desktop.noctalia.enable) {
      enable = true;
      settings = {
        portal = true;
        lat = 52.52;
        lng = 8.524;
        usegeoclue = false;
      };
      darkModeScripts.gtk-theme = "${switchDark}/bin/switch-theme-dark";
      lightModeScripts.gtk-theme = "${switchLight}/bin/switch-theme-light";
    };
  };
}
