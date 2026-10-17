{ config, lib, ... }:
{
  options.hardware.isPhysical = lib.mkEnableOption "Physical hardware optimizations";

  imports = [
    ./amd-gpu.nix
    ./amd-kvm.nix
    ./intel-gpu.nix
    ./nvidia-disable.nix
    ./ryzen-tdp.nix
  ];

  config = lib.mkIf config.hardware.isPhysical {
    services.fwupd.enable = lib.mkDefault true;
    # Upstream defaults updateMicrocode to plain false (decoupled from
    # enableRedistributableFirmware), so this mkDefault is load-bearing for
    # every physical host — previously repeated per host in three styles.
    # Both vendors on: the wrong-vendor ucode blob is inert (the early
    # kernel loader matches vendor/model; distro initrds ship both too).
    hardware = {
      enableRedistributableFirmware = lib.mkDefault true;
      cpu = {
        amd.updateMicrocode = lib.mkDefault true;
        intel.updateMicrocode = lib.mkDefault true;
      };
    };
  };
}
