{ mainUser, ... }:

{
  imports = [
    ./browsers.nix
    ./git.nix
    ./terminal.nix
    ./theme.nix
    ./winapps.nix
  ];

  programs.home-manager.enable = true;

  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";

  home.sessionVariables = {
    NH_FLAKE = "/home/${mainUser}/nixos-config";
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
