{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.intel-gpu;
in
{
  options.hardware.intel-gpu = {
    enable = lib.mkEnableOption "Intel GPU support";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
