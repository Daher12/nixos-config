{
  config,
  lib,
  mainUser,
  pkgs,
  ...
}:

let
  cfg = config.core.users;
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
    # Explicit nesting ensures cfg.zsh exists
    zsh = {
      theme = lib.mkOption {
        type = lib.types.str;
        default = "agnoster";
        description = "Oh-My-Zsh theme";
      };
    };
  };

  config = {
    # SOPS password secret (conditional on features.sops.enable)
    sops.secrets."${mainUser}_password_hash" = lib.mkIf (config.features.sops.enable or false) {
      neededForUsers = true;
      sopsFile = ../../secrets/hosts/${config.networking.hostName}.yaml;
    };

    users = {
      mutableUsers = false;

      # Explicit lock: no interactive prompt surface; shadow state unambiguous
      # users.root.hashedPassword = "!";

      # Emergency fallback: root SSH if SOPS decryption fails entirely.
      # Declared in Nix store — immune to runtime state failures.
      #users.root.openssh.authorizedKeys.keys = [
      #  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnjF7oAcgBgKQWU/JKFf2Pa+23APKg1ELceDMEgewiu emergency-root@nixos" # REPLACE
      #];

      users.${mainUser} = {
        isNormalUser = true;
        inherit (cfg) description;
        group = mainUser;

        # Reads SOPS secret directly; activation guaranteed by neededForUsers = true
        hashedPasswordFile = lib.mkIf (config.features.sops.enable or false
        ) config.sops.secrets."${mainUser}_password_hash".path;

        shell = pkgs.${cfg.defaultShell};
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "adbusers"
          "render"
        ];
      };

      groups.${mainUser} = { };
    };

    security = {
      sudo = {
        wheelNeedsPassword = true;
        extraConfig = ''
          Defaults timestamp_timeout=${toString cfg.sudoTimeout}
          Defaults !tty_tickets
        '';
      };
      rtkit.enable = lib.mkDefault true;
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
      zoxide.enable = lib.mkDefault true;
      adb.enable = lib.mkDefault true;
    };

    services = {
      pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        alsa.support32Bit = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
        jack.enable = lib.mkDefault true;
        extraConfig.pipewire = {
          "10-clock-rate" = {
            "context.properties" = {
              "default.clock.rate" = 48000;
              "default.clock.quantum" = 1024;
              "default.clock.min-quantum" = 512;
              "default.clock.max-quantum" = 2048;
            };
          };
        };
      };

      libinput.enable = lib.mkDefault true;
      fwupd.enable = lib.mkDefault true;
      logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    };

    systemd = {
      settings.Manager = {
        DefaultTimeoutStopSec = lib.mkDefault "30s";
        DefaultTimeoutStartSec = lib.mkDefault "90s";
      };
      coredump.enable = false;
    };

    documentation = {
      enable = false;
      nixos.enable = false;
      man.enable = false;
      info.enable = false;
      doc.enable = false;
    };

    # Priority 900: nixpkgs sets this at default priority (1000), causing merge conflicts
    boot.kernel.sysctl = {
      "vm.max_map_count" = lib.mkOverride 900 1048576;
      "vm.dirty_ratio" = lib.mkDefault 10;
      "vm.dirty_background_ratio" = lib.mkDefault 5;
      "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
      "vm.dirty_expire_centisecs" = lib.mkDefault 3000;
      "fs.file-max" = lib.mkDefault 2097152;
      "fs.inotify.max_user_watches" = lib.mkOverride 900 524288;
    };
  };
}
