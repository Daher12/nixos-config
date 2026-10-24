{
  config,
  lib,
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

    boot = {
      initrd.kernelModules = [ "amdgpu" ];
    };

    # Mesa provides both VA-API (radeonsi) and VDPAU (libvdpau_radeonsi)
    # natively for AMD — no extraPackages needed. Deliberately absent
    # since 2026-10-24, none had a consumer in the fleet:
    #   rocmPackages.clr — no OpenCL user anywhere
    #   libva-vdpau-driver — VA-API-on-VDPAU bridge for NVIDIA; inert with
    #     LIBVA_DRIVER_NAME=radeonsi
    #   libvdpau-va-gl + VDPAU_DRIVER=va_gl — routed VDPAU consumers
    #     through a slow VA-API/OpenGL wrapper instead of Mesa's hardware
    #     radeonsi path
    #   enable32Bit — no 32-bit (Steam/Wine) workload on any AMD host
    hardware.graphics.enable = true;

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
    };
  };
}
