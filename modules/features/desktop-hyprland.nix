{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.desktop-hyprland;
in
{
  options.features.desktop-hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop with DankMaterialShell and DankGreeter (mutually exclusive with features.desktop-gnome)";

    withUWSM = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch Hyprland through uwsm for proper systemd session targets. Also required to scope DMS to the Hyprland session only.";
    };

    dms = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "DankMaterialShell desktop shell (bar, launcher, notifications, lock screen, idle, wallpapers)";
      };

      systemdTarget = lib.mkOption {
        type = lib.types.str;
        default = "wayland-session@Hyprland.target";
        description = "User target that pulls in dms.service. The package default (graphical-session.target) would start DMS in any graphical session; the uwsm target keeps it bound to Hyprland.";
      };
    };

    greeter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "DankGreeter login screen (greetd-backed, runs on Hyprland, themed from the user's DMS settings)";
      };

      configHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/${mainUser}";
        description = "Home whose DankMaterialShell settings theme the greeter (configHome must be readable at greeter time)";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = builtins.hasAttr "home-manager" config;
            message = "features.desktop-hyprland requires home-manager to be included via mkHost";
          }
          {
            assertion = !config.features.desktop-gnome.enable;
            message = "features.desktop-hyprland and features.desktop-gnome are mutually exclusive — switch via the flake attrs (yoga = Hyprland, yoga-gnome = GNOME)";
          }
        ];

        # Registers the Hyprland session for the greeter and adds the
        # Hyprland portal.
        programs.hyprland = {
          enable = true;
          withUWSM = lib.mkDefault cfg.withUWSM;
          xwayland.enable = lib.mkDefault true;
        };

        # GUI privilege prompts (GNOME Shell is not around to provide one;
        # DMS does not ship an agent either).
        environment.systemPackages = with pkgs; [
          hyprpolkitagent
          # Handful of GTK apps the Hyprland session relies on (previously
          # pulled in by desktop-gnome): file manager + viewers used by the
          # binds and float rules in home/hyprland.nix.
          nautilus
          loupe
          file-roller
          gnome-text-editor
          gnome-calculator
          wl-clipboard
        ];

        # Nautilus trash/mount support, dconf for home-manager theme settings.
        services.gvfs.enable = true;
        programs.dconf.enable = lib.mkDefault true;

        # Secrets: gnome-keyring with unlock at greeter login (PAM service of
        # the greetd-backed DankGreeter).
        services.gnome.gnome-keyring.enable = true;
        security.pam.services.greetd.enableGnomeKeyring = true;

        # File dialogs etc. without the GNOME portal: Hyprland portal (added
        # by programs.hyprland) + gtk portal.
        xdg.portal = {
          enable = true;
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        # Flip the home-manager side (Lua config) on for the user, mirroring
        # how desktop-gnome pushes dconf settings down.
        home-manager.users.${mainUser}.desktop.hyprland.enable = lib.mkDefault true;
      }

      (lib.mkIf cfg.dms.enable {
        programs.dms-shell = {
          enable = true;
          systemd = {
            enable = true;
            target = cfg.dms.systemdTarget;
          };
          # Wallpaper-driven colors: matugen recolors the DMS shell, GTK and
          # Firefox from the current wallpaper. darkman + switch-theme are
          # auto-disabled on this attr (home/theme.nix) so they don't fight
          # matugen over ~/.config/gtk-4.0 and GTK_THEME. A static Nord DMS
          # theme stays shipped (home/hyprland.nix) as the fallback for when
          # you turn dynamic theming off in DMS Settings.
          enableDynamicTheming = true;
          # No khal/vdirsyncer calendar backend in use.
          enableCalendarEvents = false;
        };

        # TLP (laptop profile) owns power management; power-profiles-daemon
        # (mkDefault true via programs.dms-shell) would conflict with it.
        services.power-profiles-daemon.enable = false;
      })

      (lib.mkIf cfg.greeter.enable {
        services.displayManager.dms-greeter = {
          enable = true;
          compositor.name = "hyprland";
          configHome = cfg.greeter.configHome;
        };
        # Two session entries ship with hyprland ("hyprland" bare and
        # "hyprland-uwsm"). Preselect the uwsm one: dms.service is bound to
        # wayland-session@Hyprland.target, which only the uwsm session
        # activates — picking the bare session would start Hyprland without DMS.
        services.displayManager.defaultSession = "hyprland-uwsm";
      })
    ]
  );
}
