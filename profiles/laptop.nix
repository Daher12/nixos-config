{ lib, ... }:

{
  features = {
    bluetooth.enable = lib.mkDefault true;
    fonts.enable = lib.mkDefault true;
    power-tlp.enable = lib.mkDefault true;
    zram.enable = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
  };

  core.boot.silent = lib.mkDefault true;
  core.nix.gc.automatic = lib.mkDefault true;
  core.secureboot.enable = lib.mkDefault true;

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
