{ ... }:

{
  imports = [
    ../../home
  ];

  # Match system.stateVersion in hosts/latitude/default.nix
  home.stateVersion = "25.05";
}
