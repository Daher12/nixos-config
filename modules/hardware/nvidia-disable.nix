{ config, lib, ... }:

let
  cfg = config.hardware.nvidia.disable;
in
{
  options.hardware.nvidia.disable = {
    enable = lib.mkEnableOption "NVIDIA dGPU removal via udev (aim: 0W draw)";
  };

  config = lib.mkIf cfg.enable {
    # 1) Block kernel drivers from binding
    # boot.blacklistedKernelModules prevents auto-load by hardware probing.
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

    # 2) Udev “remove” rules
    # Matches widely-used nixos-hardware logic to cut power to the PCI lane.
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

    # 3) Wayland-only: no Xorg knobs here.
    # Optional “fail fast” guard: if someone turns on X11 + nvidia, this config becomes contradictory.
    assertions = [
      {
        assertion = !(config.services.xserver.enable or false);
        message = "hardware.nvidia.disable.enable=true is intended for Wayland-only (services.xserver.enable must be false).";
      }
    ];
  };
}
