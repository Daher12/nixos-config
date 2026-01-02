{ config, lib, mainUser, ... }:

{
  imports = [
    ../../home
  ];

  programs.home-manager.enable = true;

  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    NH_FLAKE = "/home/${mainUser}/nixos-config";
    EDITOR = "ox";
    VISUAL = "ox";
    NIXOS_OZONE_WL = "1";
  };

  programs.winapps.enable = true;

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "blur-my-shell@aunetx"
      ];
    };
  };
}
