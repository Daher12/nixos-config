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
    ];
    allowOther = true;
  };
}
