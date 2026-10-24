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
      # Stage-2 load only: nothing virtualizes inside the initrd, and
      # initrd inclusion just bloats every initrd (kvm/kvm-amd lived in
      # initrd.kernelModules until 2026-10-24).
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
