{ config, lib, pkgs, ... }:

let
  cfg = config.core.boot;
in
{
  options.core.boot = {
    silent = lib.mkEnableOption "silent boot with Plymouth";
    
    plymouth.theme = lib.mkOption {
      type = lib.types.str;
      default = "bgrt";
      description = "Plymouth theme to use";
    };

    tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Mount /tmp in RAM";
      };
      
      size = lib.mkOption {
        type = lib.types.str;
        default = "80%";
        description = "Size of tmpfs";
      };
    };
  };

  config = {
    boot = {
      consoleLogLevel = if cfg.silent then 0 else 3;
      initrd.verbose = !cfg.silent;
      initrd.systemd.enable = true;
      
      initrd.compressor = "zstd";
      initrd.compressorArgs = [ "-3" "-T0" ];
      
      plymouth = lib.mkIf cfg.silent {
        enable = true;
        theme = cfg.plymouth.theme;
      };

      kernelParams = lib.mkIf cfg.silent [
        "quiet"
        "splash"
        "vt.global_cursor_default=0"
        "systemd.show_status=false"
        "udev.log_level=3"
        "loglevel=3"
        "systemd.log_level=warning"
        "nowatchdog"
        "nmi_watchdog=0"
      ];

      loader.systemd-boot.enable = lib.mkForce false;
      loader.efi.canTouchEfiVariables = true;
    };

    boot.tmp = lib.mkIf cfg.tmpfs.enable {
      useTmpfs = true;
      tmpfsSize = cfg.tmpfs.size;
      cleanOnBoot = true;
    };
  };
}
