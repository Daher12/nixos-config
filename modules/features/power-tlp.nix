{ config, lib, ... }:

let
  cfg = config.features.power-tlp;
in
{
  options.features.power-tlp = {
    enable = lib.mkEnableOption "TLP power management";

    # TLP's power-profiles-daemon-compatible D-Bus interface (tlp-pd): makes
    # the three TLP 1.9+ profiles (performance / balanced / power-saver)
    # switchable from the desktop via the standard
    # org.freedesktop.UPower.PowerProfiles API, and queryable with
    # `tlp-stat -m`. Classic AC/battery auto-switching keeps working on top.
    # Asserted against power-profiles-daemon by the upstream module — which
    # this module force-disables below.
    pd = {
      enable = lib.mkEnableOption "TLP's tlp-pd D-Bus profile interface";
    };

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
      pd.enable = cfg.pd.enable;
      settings = lib.mkMerge [
        {
          # powersave (TLP's own default), NOT schedutil: under amd/intel_pstate
          # in active mode the only valid governors are performance/powersave —
          # schedutil gets rejected. TLP then drives behavior via EPP, not the
          # governor. Both fleet laptops run pstate active.
          CPU_SCALING_GOVERNOR_ON_AC = lib.mkDefault "powersave";
          CPU_SCALING_GOVERNOR_ON_BAT = lib.mkDefault "powersave";
          USB_AUTOSUSPEND = lib.mkDefault 1;
          USB_EXCLUDE_AUDIO = lib.mkDefault 1;
        }
        cfg.settings
      ];
    };
  };
}
