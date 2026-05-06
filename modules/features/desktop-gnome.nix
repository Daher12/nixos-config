{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.desktop-gnome;
in
{
  options.features.desktop-gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic login";
    };

    autoLoginUser = lib.mkOption {
      type = lib.types.str;
      default = mainUser;
      description = "User to automatically log in";
    };

    experimentalFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "scale-monitor-framebuffer"
        "xwayland-native-scaling"
      ];
      description = "Mutter experimental features";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.autoLogin -> cfg.autoLoginUser != "";
        message = "autoLoginUser must be set when autoLogin is enabled";
      }
    ];

    services = {
      xserver = {
        enable = lib.mkDefault true;
        xkb.layout = "de";
        excludePackages = [ pkgs.xterm ];
      };

      displayManager = {
        gdm = {
          enable = true;
          wayland = true;
        };
        autoLogin = lib.mkIf cfg.autoLogin {
          enable = true;
          user = cfg.autoLoginUser;
        };
      };

      desktopManager.gnome.enable = true;

      gnome = {
        games.enable = false;
        core-apps.enable = false;
        tinysparql.enable = lib.mkForce false;
        localsearch.enable = lib.mkForce false;
        evolution-data-server.enable = lib.mkForce false;
        gnome-online-accounts.enable = lib.mkForce false;
        gnome-browser-connector.enable = false;
        gnome-keyring.enable = true;
      };

      udev.packages = [ pkgs.gnome-settings-daemon ];
    };

    security.pam.services.gdm.enableGnomeKeyring = true;

    # Apply experimental features via home-manager
    home-manager.users.${mainUser}.dconf.settings = {
      "org/gnome/mutter" = {
        experimental-features = cfg.experimentalFeatures;
      };
    };

    environment = {
      gnome.excludePackages = [
        pkgs.gnome-photos
        pkgs.gnome-tour
        pkgs.gedit
        pkgs.cheese
        pkgs.gnome-music
        pkgs.epiphany
        pkgs.geary
        pkgs.totem
        pkgs.gnome-contacts
        pkgs.gnome-weather
        pkgs.gnome-maps
        pkgs.yelp
        pkgs.seahorse
        pkgs.gnome-user-docs
        pkgs.gnome-calendar
        pkgs.simple-scan
        pkgs.gnome-logs
        pkgs.gnome-connections
      ];

      systemPackages = [
        pkgs.nautilus
        pkgs.file-roller
        pkgs.gnome-tweaks
        pkgs.loupe
        pkgs.wl-clipboard
        pkgs.gnome-text-editor
        pkgs.gnome-calculator
        pkgs.gnome-themes-extra
        pkgs.gnomeExtensions.user-themes
        pkgs.gnomeExtensions.blur-my-shell
        pkgs.gtk3
        pkgs.papers
      ];
    };

    programs.dconf.enable = lib.mkDefault true;
  };
}
