_: {
  imports = [
    ../../home
  ];

  home.stateVersion = "25.11";

  browsers = {
    firefox.enable = true;
    brave.enable = true;
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

    ".local/share/keyrings"
    ".mozilla/firefox"
    ".config/BraveSoftware/Brave-Browser/Default"
    ".local/state/wireplumber"
    "nixos-config"
  ];

  files = [
    ".config/fish/fish_variables"
  ];
 };
}