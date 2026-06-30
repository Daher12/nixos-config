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
    sops.secrets = lib.mkIf sopsEnabled {
      "${mainUser}_password_hash" = {
        neededForUsers = true;
        sopsFile = ../../secrets/hosts/${config.networking.hostName}.yaml;
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
          "kvm"
        ];
      };

      groups.${mainUser} = { };
    };

    security.sudo = {
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults timestamp_timeout=${toString cfg.sudoTimeout}
        Defaults !tty_tickets
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
