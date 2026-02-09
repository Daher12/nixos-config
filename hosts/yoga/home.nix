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
      ".local/share/zoxide
      ".local/share/direnv"
      "nixos-config"
    ];
    files = [
      ".bash_history"          # Bash history
    ];
    allowOther = true;
  };
}
