{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.amd-gpu;
in
{
  options.hardware.amd-gpu = {
    enable = lib.mkEnableOption "AMD GPU support";
  };

  config = lib.mkIf cfg.enable {

    # boot.initrd.kernelModules = [ "amdgpu" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [
        pkgs.rocmPackages.clr
        pkgs.libva-vdpau-driver
        pkgs.libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
      VDPAU_DRIVER = "va_gl";
    };
  };
}
