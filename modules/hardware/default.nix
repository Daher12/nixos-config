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
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
