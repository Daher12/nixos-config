{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.intel-qsv;
in
{
  options.features.intel-qsv = {
    enable = lib.mkEnableOption "Intel QuickSync Video hardware transcoding";

    deviceId = lib.mkOption {
      type = lib.types.str;
      default = "46d1";
      description = "Intel GPU device ID (e.g., 46d1 for N100)";
    };

    renderNode = lib.mkOption {
      type = lib.types.str;
      default = "/dev/dri/renderD128";
      description = "Render device node for hardware acceleration";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.enableAllFirmware = true;

    hardware.graphics = {
      enable = true;
      enable32Bit = false;

      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
      ];
    };

    environment.variables = {
      LIBVA_DRIVER_NAME = "iHD";
      LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
      ONEVPL_SEARCH_PATH = "${pkgs.vpl-gpu-rt}/lib";
      OCL_ICD_VENDORS = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";
    };

    boot.kernelParams = [
      "i915.force_probe=${cfg.deviceId}"
      "i915.enable_guc=3"
    ];

    services.udev.extraRules = ''
      KERNEL=="renderD*", GROUP="video", MODE="0666"
    '';

    environment.systemPackages = with pkgs; [
      libva-utils
      intel-gpu-tools
    ];
  };
}
