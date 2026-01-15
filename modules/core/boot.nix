{ config, lib, ... }:

let
  cfg = config.core.boot;
in
{
  options.core.boot = {
    silent = lib.mkEnableOption "silent boot with Plymouth";

    plymouth.theme = lib.mkOption {
      type = lib.types.enum [ "bgrt" "spinner" "script" "text" ];
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

      initrd = {
        verbose = !cfg.silent;
        systemd.enable = true;
        compressor = "zstd";
        compressorArgs = [
          "-3"
          "-T0"
        ];
      };

      plymouth = lib.mkIf cfg.silent {
        enable = true;
        inherit (cfg.plymouth) theme;
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

      loader = {
        systemd-boot.enable = lib.mkDefault false;
        efi.canTouchEfiVariables = true;
      };

      tmp = lib.mkIf cfg.tmpfs.enable {
        useTmpfs = true;
        tmpfsSize = cfg.tmpfs.size;
        cleanOnBoot = true;
      };
    };

    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    '';
  };
}
