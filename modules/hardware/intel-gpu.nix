{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.intel-gpu;
in
{
  options.hardware.intel-gpu = {
    enable = lib.mkEnableOption "Intel GPU support";
    enableOpenCL = lib.mkEnableOption "OpenCL (Compute Runtime)";
    enableVpl = lib.mkEnableOption "VPL (Video Processing Library)";
    enableGuc = lib.mkEnableOption "GuC/HuC Firmware";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Base Graphics Stack
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          libvdpau-va-gl
        ] 
        ++ lib.optional cfg.enableOpenCL pkgs.intel-compute-runtime
        ++ lib.optional cfg.enableVpl pkgs.vpl-gpu-rt;
      };

      # Host-level debugging (optional, strictly for user shell)
      environment.variables = lib.optionalAttrs cfg.enableVpl {
        LIBVA_DRIVER_NAME = "iHD";
      };
    }

    # Conditional Firmware Enablement (The "Safe" Pattern)
    (lib.mkIf cfg.enableGuc {
      hardware.enableRedistributableFirmware = true;
      boot.kernelParams = [ "i915.enable_guc=3" ];
    })
  ]);
}
