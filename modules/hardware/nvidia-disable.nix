{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.nvidia.disable;
in
{
  options.hardware.nvidia.disable = {
    enable = lib.mkEnableOption "completely disable Nvidia GPU";
  };

  config = lib.mkIf cfg.enable {
    # FIX: Grouped "boot" attributes to satisfy Statix
    boot = {
      blacklistedKernelModules = [
        "nouveau"
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
      ];

      kernelParams = [
        "nouveau.modeset=0"
        "rd.driver.blacklist=nouveau"
      ];

      extraModprobeConfig = ''
        blacklist nouveau
        options nouveau modeset=0
      '';
    };

    services.udev.extraRules = ''
      # Remove NVIDIA USB xHCI Host Controller devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA USB Type-C UCSI devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA VGA/3D controller devices
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
    '';
  };
}
