{ config, lib, ... }:

let
  cfg = config.core.boot;
  # Detect if the Secure Boot feature module is active
  sbActive = config.features.secureboot.enable or false;
in
{
  options.core.boot = {
    silent = lib.mkEnableOption "silent boot with Plymouth";
    plymouth.theme = lib.mkOption {
      type = lib.types.enum [
        "bgrt"
        "spinner"
        "script"
        "text"
      ];
      description = "Plymouth theme to use";
    };
    tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount /tmp in RAM";
      };
      size = lib.mkOption {
        type = lib.types.str;
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
        # Standard boot only enabled if Secure Boot feature is OFF
        systemd-boot = {
          enable = lib.mkIf (!sbActive) true;
          configurationLimit = lib.mkDefault 10;
          consoleMode = lib.mkDefault "max";
        };
        efi.canTouchEfiVariables = true;
        # Keep ESP mountpoint consistent with Disko (ESP mounted at /boot)
        # and with the installer script's strict /mnt/boot mountpoint check.
        efi.efiSysMountPoint = lib.mkDefault "/boot";
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
