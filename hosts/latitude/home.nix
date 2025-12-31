{ config, pkgs, lib, unstable, palette, ... }:

{
  imports = [
    # Shared Visuals & Theming
    ../../home/theme.nix

    # Shared Applications & Tools
    ../../home/terminal.nix
    ../../home/browsers.nix
    ../../home/git.nix
    ../../home/winapps.nix
  ];

  # Home Manager CLI
  programs.home-manager.enable = true;

  # --- User Configuration ---
  home.username      = "dk";
  home.homeDirectory = "/home/dk";
  home.stateVersion  = "25.05";

  # --- Session Variables ---
  home.sessionVariables = {
    # Point to the root of the unified flake
    NH_FLAKE       = "/home/dk/nixos-config"; 
    EDITOR         = "ox";
    VISUAL         = "ox";
    
    # [OPTIMIZATION] Force Wayland for Electron apps (VSCode, Discord)
    NIXOS_OZONE_WL = "1";
  };

  # --- GNOME Settings ---
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
