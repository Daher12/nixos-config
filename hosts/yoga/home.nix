{ ... }:

{
  imports = [
    ../../home
  ];

  home.stateVersion = "25.11";

  programs.winapps.enable = false;
  
  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };
}
