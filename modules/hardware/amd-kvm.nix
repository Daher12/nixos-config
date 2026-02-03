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
    # Load KVM early to ensure /dev/kvm exists before libvirtd/QEMU starts.
    boot.initrd.kernelModules = [
      "kvm"
      "kvm-amd"
    ];

    boot.kernelModules = [
      "kvm"
      "kvm-amd"
    ];

    boot.extraModprobeConfig = ''
      options kvm_amd avic=1 npt=1
    '';
  };
}

