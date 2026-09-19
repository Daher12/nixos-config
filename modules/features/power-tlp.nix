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
    assertions = [
      {
        assertion = !config.services.power-profiles-daemon.enable;
        message = "TLP and power-profiles-daemon are mutually exclusive. Disable one.";
      }
    ];
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
