{ config, lib, ... }:

let
  cfg = config.features.power-tlp;
in
{
  options.features.power-tlp = {
    enable = lib.mkEnableOption "TLP power management";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "TLP configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    # Plain false: any host-level `true` conflicts loudly at eval time.
    # (The old mutual-exclusion assertion was dead — it read the fixed
    # point AFTER this assignment, so it could never fire — removed
    # 2026-11-18 audit.)
    services.power-profiles-daemon.enable = false;

    services.tlp = {
      enable = true;
      settings = lib.mkMerge [
        {
          CPU_SCALING_GOVERNOR_ON_AC = lib.mkDefault "schedutil";
          CPU_SCALING_GOVERNOR_ON_BAT = lib.mkDefault "schedutil";
          USB_AUTOSUSPEND = lib.mkDefault 1;
          USB_EXCLUDE_AUDIO = lib.mkDefault 1;
        }
        cfg.settings
      ];
    };
  };
}
