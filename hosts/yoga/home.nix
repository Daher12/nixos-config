_: # No arguments used in this module
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
      # Persist entire Firefox directory: avoids profile-name fragility.
      # HM creates profiles at .mozilla/firefox/<attr-name> but Firefox itself
      # can create hashed-prefix dirs (e.g. abcdef12.default-release) on first
      # launch before HM activation; granular file persistence would silently miss these.
      ".mozilla/firefox"
      ".config/BraveSoftware/Brave-Browser/Default"
      ".local/state/wireplumber"
      "nixos-config"
    ];
    files = [
      ".config/fish/fish_variables"
      ".config/sops/age/keys.txt"
    ];
  };
}
