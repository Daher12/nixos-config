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
      # Ensure /dev/kvm exists early (initrd) and stays available.
      initrd.kernelModules = [
        "kvm"
        "kvm-amd"
      ];

      # mkAfter to avoid clobbering other boot.kernelModules definitions
      kernelModules = lib.mkAfter [
        "kvm"
        "kvm-amd"
      ];

      extraModprobeConfig = ''
        options kvm_amd avic=1 npt=1
      '';
    };
  };
}
