{ config, lib, ... }:

let
  cfg = config.hardware.nvidia-disable;
in
{
  options.hardware.nvidia-disable = {
    enable = lib.mkEnableOption "NVIDIA GPU removal (0W power draw)";
  };

  config = lib.mkIf cfg.enable {
    boot.blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    boot.extraModprobeConfig = ''
      blacklist nouveau
      options nouveau modeset=0
    '';

    services.udev.extraRules = ''
      # Remove NVIDIA PCI devices (Vendor ID 0x10de)
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", \
        ATTR{class}=="0x0c0330|0x0c8000|0x040300|0x030000", \
        ATTR{power/control}="auto", ATTR{remove}="1"
    '';
  };
}
