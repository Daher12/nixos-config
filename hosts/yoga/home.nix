_: # No arguments used in this module
let
  # NOTE: Check your actual firefox profile name.
  # It might be 'default' or a hash.
  firefoxProfile = ".mozilla/firefox/default";
in
{
  imports = [
    ../../home
  ];

  home.stateVersion = "25.11";
  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };

  home.persistence."/persist" = {
    # Only app-state dotfiles remain here; XDG dirs moved to system
    # persistence for hideMounts + allowTrash support
    directories = [
      {
        directory = ".ssh";
        mode = "0700";
      }
      {
        directory = ".gnupg";
        mode = "0700";
      }
      ".local/share/keyrings"
      "${firefoxProfile}/storage"
      ".config/BraveSoftware/Brave-Browser/Default"
      ".local/state/wireplumber"
      "nixos-config"
    ];
    files = [
      ".config/fish/fish_variables"
      ".config/sops/age/keys.txt"
      "${firefoxProfile}/places.sqlite"
      "${firefoxProfile}/favicons.sqlite"
      "${firefoxProfile}/prefs.js"
    ];
  };
}
