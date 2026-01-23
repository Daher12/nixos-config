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

      desktopManager.gnome = {
        enable = true;
        extraGSettingsOverridePackages = [ pkgs.mutter ];
      };

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

    environment = {
      gnome.excludePackages = with pkgs; [
        gnome-photos
        gnome-tour
        gedit
        cheese
        gnome-music
        epiphany
        geary
        totem
        gnome-contacts
        gnome-weather
        gnome-maps
        yelp
        seahorse
        gnome-user-docs
        gnome-calendar
        simple-scan
        gnome-logs
        gnome-connections
      ];

      systemPackages = with pkgs; [
        nautilus
        file-roller
        gnome-tweaks
        loupe
        wl-clipboard
        gnome-text-editor
        gnome-calculator
        gnome-themes-extra
        gnomeExtensions.user-themes
        gnomeExtensions.blur-my-shell
      ];
    };

    programs.dconf.enable = lib.mkDefault true;
  };
}
