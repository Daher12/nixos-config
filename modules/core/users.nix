{
  config,
  lib,
  mainUser,
  pkgs,
  ...
}:

let
  cfg = config.core.users;
  sopsEnabled = config.features.sops.enable or false;
in
{
  options.core.users = {
    sudoTimeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Sudo password timeout in minutes";
    };
    description = lib.mkOption {
      type = lib.types.str;
      default = "User";
      description = "User full name";
    };
    defaultShell = lib.mkOption {
      type = lib.types.enum [
        "fish"
        "zsh"
        "bash"
      ];
      default = "fish";
      description = "Default shell for main user";
    };
    zsh = {
      theme = lib.mkOption {
        type = lib.types.str;
        default = "agnoster";
        description = "Oh-My-Zsh theme";
      };
    };
  };

  config = {
    # With mutableUsers = false, a main user with neither sops-provided nor
    # explicitly set credentials simply cannot log in — fail the eval
    # loudly instead of producing an unloginable system.
    assertions = [
      {
        assertion =
          sopsEnabled
          || lib.any (v: v != null) (
            map (k: config.users.users.${mainUser}.${k}) [
              "password"
              "hashedPassword"
              "initialPassword"
              "initialHashedPassword"
              "hashedPasswordFile"
            ]
          );
        message = "core.users: features.sops is disabled and no password option is set for ${mainUser}; with users.mutableUsers = false this creates a user that cannot log in. Enable features.sops or set users.users.${mainUser}.hashedPasswordFile.";
      }
    ];

    sops.secrets = lib.mkIf sopsEnabled {
      "${mainUser}_password_hash" = {
        neededForUsers = true;
      };
    };

    users = {
      mutableUsers = false;

      users.${mainUser} = {
        isNormalUser = true;
        inherit (cfg) description;
        group = mainUser;
        hashedPasswordFile = lib.mkIf sopsEnabled config.sops.secrets."${mainUser}_password_hash".path;
        shell = pkgs.${cfg.defaultShell};
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "render"
        ];
      };

      groups.${mainUser} = { };
    };

    security.sudo = {
      wheelNeedsPassword = true;
      # Per-tty tickets stay enabled (the default): one successful sudo
      # must not unlock every terminal for the timeout window.
      extraConfig = ''
        Defaults timestamp_timeout=${toString cfg.sudoTimeout}
      '';
    };

    programs = {
      fish.enable = lib.mkDefault (cfg.defaultShell == "fish");
      zsh = lib.mkIf (cfg.defaultShell == "zsh") {
        enable = true;
        enableCompletion = true;
        autosuggestions.enable = true;
        syntaxHighlighting.enable = true;
        histSize = 10000;
        ohMyZsh = {
          enable = true;
          inherit (cfg.zsh) theme;
        };
      };
    };
  };
}
