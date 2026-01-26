{ ... }:

{
  imports = [
    ../../home
  ];

  home.stateVersion = "25.11";

  programs.winapps.enable = false;
}
