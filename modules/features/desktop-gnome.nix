{ config, lib, pkgs, ... }:

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
      default = "";
      description = "User to automatically log in";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "de";
      excludePackages = [ pkgs.xterm ];
    };

    services.displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    services.displayManager.autoLogin = lib.mkIf cfg.autoLogin {
      enable = true;
      user = cfg.autoLoginUser;
    };

    services.desktopManager.gnome = {
      enable = true;
      extraGSettingsOverridePackages = [ pkgs.mutter ];
      extraGSettingsOverrides = ''
        [org.gnome.mutter]
        experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
      '';
    };

    services.gnome = {
      games.enable = false;
      core-apps.enable = false;
      tinysparql.enable = lib.mkForce false;
      localsearch.enable = lib.mkForce false;
      evolution-data-server.enable = lib.mkForce false;
      gnome-online-accounts.enable = lib.mkForce false;
      gnome-browser-connector.enable = false;
      gnome-keyring.enable = true;
    };

    security.pam.services.gdm.enableGnomeKeyring = true;

    environment.gnome.excludePackages = (with pkgs; [
      gnome-photos gnome-tour gedit cheese gnome-music 
      epiphany geary totem gnome-contacts gnome-weather 
      gnome-maps yelp seahorse
      gnome-user-docs
      gnome-calendar
      simple-scan
      gnome-logs
      gnome-connections
    ]);

    environment.systemPackages = with pkgs; [
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

    services.udev.packages = with pkgs; [ gnome-settings-daemon ];
    programs.dconf.enable = true;
  };
}
