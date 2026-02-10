_: # No arguments used in this module
let
  # NOTE: Check your actual firefox profile name.
  # It might be 'default' or a hash.
  firefoxProfile = ".mozilla/firefox/default";
  braveProfile = ".config/BraveSoftware/Brave-Browser/Default";
in
{
  home.stateVersion = "25.11";
  
  home.persistence."/persist" = {
    # Fix: Removed deprecated allowOther
    directories = [
      "Documents"
      "Downloads"
      "nixos-config"
      ".ssh"
      ".gnupg"
      ".local/share/keyrings" 
      "${firefoxProfile}/storage"
      "${braveProfile}/Local Extension Settings"
      ".local/state/wireplumber"
    ];
    files = [
      ".config/fish/fish_variables"
      "${firefoxProfile}/places.sqlite"
      "${firefoxProfile}/favicons.sqlite"
      "${firefoxProfile}/prefs.js"
      "${braveProfile}/History"
      "${braveProfile}/Bookmarks"
      "${braveProfile}/Login Data"
      "${braveProfile}/Preferences"
    ];
  };
}
