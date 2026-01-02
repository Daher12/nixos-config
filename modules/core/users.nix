# modules/core/users.nix
{ config, lib, ... }:

let
  cfg = config.core.users;
in
{
  options.core.users = {
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "dk";
      description = "Primary system user";
    };

    sudoTimeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Sudo password timeout in minutes";
    };
  };

  config = {
    users.users.${cfg.mainUser} = {
      isNormalUser = true;
      description = "David";
      group = cfg.mainUser;
      extraGroups = [ 
        "networkmanager" "wheel" "video" "audio" 
        "input" "adbusers" "render" "libvirtd" "kvm"
      ];
    };

    users.groups.${cfg.mainUser} = {};

    security.sudo = {
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults timestamp_timeout=${toString cfg.sudoTimeout}
        Defaults !tty_tickets
      '';
    };

    programs.fish.enable = true;
    programs.adb.enable = true;

    security.rtkit.enable = true;
    
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      
#      extraConfig.pipewire."92-low-latency" = {
#        context.properties = {
#          default.clock.rate = 48000;
#          default.clock.quantum = 1024;
#          default.clock.min-quantum = 512;
#          default.clock.max-quantum = 2048;
#        };
#      };
    };

    services.libinput.enable = true;
    
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    systemd.settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutStartSec = "30s";
    };

    documentation.enable = false;
    documentation.nixos.enable = false;
    documentation.man.enable = false;
    documentation.info.enable = false;
    documentation.doc.enable = false;

    services.fwupd.enable = true;
    systemd.coredump.enable = false;

    boot.kernel.sysctl = {
      "vm.max_map_count" = 1048576;
      "vm.dirty_bytes" = 268435456;
      "vm.dirty_background_bytes" = 134217728;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.dirty_expire_centisecs" = 3000;
      "fs.file-max" = 2097152;
      "fs.inotify.max_user_watches" = 524288;
    };
  };
}
