# daher12/nixos-config/nixos-config-impermanence/hosts/yoga/home.nix
{ ... }:
{
  imports = [ ../../home ];

  home.stateVersion = "25.11";

  programs.winapps.enable = false;
  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };

  home.persistence."/persist/home/dk" = {
    directories = [
      "Documents"
      "Downloads"
      ".ssh"
      ".gnupg"
      ".mozilla"
      ".local/share/keyrings"
      ".config/dconf"
      ".local/share/fish"
      ".config/fish" 
      ".local/share/zoxide"
      ".local/share/direnv"
      "nixos-config"
      ".local/state"
      ".config/BraveSoftware"
      ".cache/nix-index"
    ];
    files = [
      ".bash_history"
    ];
    allowOther = true; 
  };
}
