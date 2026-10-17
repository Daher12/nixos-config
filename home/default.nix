{
  config,
  lib,
  homeDirectory ? "/home/${mainUser}",
  mainUser,
  ...
}:

{
  imports = [
    ./battery-refresh.nix
    ./browsers.nix
    ./git.nix
    ./hyprland.nix
    ./lucid.nix
    ./opencode.nix
    ./terminal.nix
    ./theme.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = mainUser;
    inherit homeDirectory;

    sessionVariables = {
      NH_FLAKE = "${homeDirectory}/nixos-config";
      EDITOR = "ox";
      VISUAL = "ox";
      NIXOS_OZONE_WL = "1";
    };
  };

  # GNOME-shell extension pins only make sense on GNOME sessions; on the
  # lucid/Hyprland host no GNOME Shell runs, so writing them is dead state.
  dconf.settings = lib.mkIf (!config.desktop.hyprland.enable) {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "blur-my-shell@aunetx"
      ];
    };
  };
}
