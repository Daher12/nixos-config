{ config, pkgs, lib, unstable, palette, ... }:

{
  imports = [
    ../../home/theme.nix
    ../../home/terminal.nix
    ../../home/browsers.nix
    ../../home/git.nix
    ../../home/winapps.nix
  ];

  programs.home-manager.enable = true;

  home.username = "dk";
  home.homeDirectory = "/home/dk";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    NH_FLAKE = "/home/dk/nixos-config";
    EDITOR = "ox";
    VISUAL = "ox";
    NIXOS_OZONE_WL = "1";
  };

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
