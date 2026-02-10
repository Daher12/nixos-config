{ ... }:
let
  # NOTE: Check your actual firefox profile name. It might be 'default' or a hash.
  firefoxProfile = ".mozilla/firefox/default";
  braveProfile = ".config/BraveSoftware/Brave-Browser/Default";
in
{
  # ... imports and other config ...

  home.persistence."/persist/home/dk" = {
    allowOther = true;
    
    directories = [
      # --- Personal Data ---
      "Documents"
      "Downloads"
      "nixos-config"

      # --- Identity & Secrets ---
      ".ssh"
      ".gnupg"
      ".local/share/keyrings" 

      # --- Firefox: Extension Data Only ---
      "${firefoxProfile}/storage"
      
      # --- Brave: Extension Data Only ---
      "${braveProfile}/Local Extension Settings"

      # --- System State ---
      ".local/state/wireplumber" # Keep audio volume levels
    ];

    files = [
      # --- Shell ---
      ".config/fish/fish_variables"

      # --- Firefox: Surgical Files ---
      "${firefoxProfile}/places.sqlite"   # History & Bookmarks
      "${firefoxProfile}/favicons.sqlite" # Icons
      "${firefoxProfile}/prefs.js"        # UI Settings

      # --- Brave: Surgical Files ---
      "${braveProfile}/History"
      "${braveProfile}/Bookmarks"
      "${braveProfile}/Login Data"      # Passwords
      "${braveProfile}/Preferences"     # Settings
      # Note: Brave might complain about "Profile in use" if lockfiles persist.
      # Usually impermanence handles this, but if Brave crashes, delete 'SingletonLock'.
    ];
  };
}
