{ config, lib, ... }:

let
  cfg = config.features.oomd;
in
{
  options.features.oomd = {
    enable = lib.mkEnableOption "systemd-oomd memory pressure handling";
  };

  config = lib.mkIf cfg.enable {
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableUserSlices = true;
      enableSystemSlice = true;
    };

    # Prevent conflict with earlyoom
    services.earlyoom.enable = lib.mkForce false;
  };
}
