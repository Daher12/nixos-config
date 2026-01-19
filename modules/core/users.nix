{
  config,
  lib,
  mainUser,
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
  };

  config = {
    users.users.${mainUser} = {
      isNormalUser = true;
      inherit (cfg) description;
      group = mainUser;
      extraGroups = [
        "networkmanager"
        "wheel"
        "video"
        "audio"
        "input"
        "adbusers"
        "render"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvXYwk5iekNITQ2UrkllAeaA/Ax7NusdRqmYFeGsR9p"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGFnKXecASihl/0JbGW5aoFVnYSfpfkmhma6S5VwLMd3"
      ];
    };

    users.groups.${mainUser} = { };

    security = {
      sudo = {
        wheelNeedsPassword = true;
        extraConfig = ''
          Defaults timestamp_timeout=${toString cfg.sudoTimeout}
          Defaults !tty_tickets
        '';
      };
      rtkit.enable = true;
    };

    programs.fish.enable = true;
    programs.adb.enable = true;
    services = {
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
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

      libinput.enable = true;
      fwupd.enable = true;
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
    boot.kernel.sysctl = {
      "vm.max_map_count" = 1048576;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.dirty_expire_centisecs" = 3000;
      "fs.file-max" = 2097152;
      "fs.inotify.max_user_watches" = 524288;
    };
  };
}
