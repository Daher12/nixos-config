{
  config,
  lib,
  ...
}:

let
  cfg = config.hardware.amd-kvm;
in
{
  options.hardware.amd-kvm.enable = lib.mkEnableOption "AMD KVM (kvm-amd)";

  config = lib.mkIf cfg.enable {
    boot = {
      # Load KVM early to ensure /dev/kvm exists before libvirtd/QEMU starts.
      initrd.kernelModules = [
        "kvm"
        "kvm-amd"
      ];

      kernelModules = [
        "kvm"
        "kvm-amd"
      ];

      extraModprobeConfig = ''
        options kvm_amd avic=1 npt=1
      '';
    };
  };
}
