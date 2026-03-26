{ ... }:

{
  imports = [
    ../../home
  ];

  home.stateVersion = "25.11";

  home.sessionPath = [ "/home/dk/.local/bin" ];

  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };

  programs.winapps = {
    enable = true;
    vmIP = "192.168.122.139";
    windowsDomain = "DESKTOP-DVTRQ43";
    rdpScale = 180;
  };

  home.persistence."/persist" = {
    directories = [
      {
        directory = ".ssh";
        mode = "0700";
      }
      {
        directory = ".gnupg";
        mode = "0700";
      }
      {
        directory = ".config/sops/age";
        mode = "0700";
      }
      {
        directory = ".config/fish";
        mode = "0700";
      }
      {
        directory = ".config/dconf";
        mode = "0700";
      }
      {
        directory = ".config/winapps";
        mode = "0700";
      }
      {
        directory = ".config/freerdp";
        mode = "0700";
      }
      {
        directory = ".local/share/fish";
        mode = "0700";
      }
      ".local/share/keyrings"
      ".mozilla/firefox"
      ".config/BraveSoftware/Brave-Browser"
      ".local/state/wireplumber"
      ".local/share/winapps/icons"
      ".local/share/applications"
      
      
    ];

    files = [
      ".oxrc"
      ".local/bin/windows"
    ];
  };
}
