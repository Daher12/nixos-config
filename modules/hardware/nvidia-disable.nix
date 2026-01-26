{ config, lib, ... }:

let
  cfg = config.hardware.nvidia.disable;

  # When set, only these PCI functions are removed (safer than vendor-wide match).
  # Example BDF: "0000:01:00.0" (include all functions e.g. .0/.1/.2 if present).
  udevRemoveRules =
    if cfg.pciAddresses != [] then
      lib.concatMapStringsSep "\n" (addr: ''
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="${addr}", ATTR{power/control}="auto", ATTR{remove}="1"
      '') cfg.pciAddresses
    else
      ''
        # Default (broad): remove NVIDIA GPU + common companion functions by class.
        # udev uses glob-style matching; keep patterns simple/predictable.
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1" # xHCI
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1" # UCSI/other
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1" # HDA audio
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03*",     ATTR{power/control}="auto", ATTR{remove}="1" # VGA/3D
      '';
in
{
  options.hardware.nvidia.disable = {
    enable = lib.mkEnableOption "NVIDIA dGPU removal via udev (aim: 0W draw)";

    pciAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "0000:01:00.0" "0000:01:00.1" "0000:01:00.2" ];
      description = "Optional allowlist of PCI BDFs to remove; when empty, uses broad vendor/class matching.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1) Block kernel drivers from auto-loading
    boot.blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    # Make early-boot behavior predictable (initrd/module autoload).
    boot.kernelParams = [
      "module_blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset"
    ];

    boot.extraModprobeConfig = ''
      blacklist nouveau
      options nouveau modeset=0
    '';

    # 2) Udev “remove” rules
    services.udev.extraRules = udevRemoveRules;
  };
}
