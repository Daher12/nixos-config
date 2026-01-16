{ lib, ... }:

{
  features = {
    bluetooth.enable = lib.mkDefault true;
    power-tlp.enable = lib.mkDefault true; 
    zram.enable = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
    kernel.variant = lib.mkDefault "zen";

    # Roaming VPN for laptops
    vpn.tailscale = {
      enable = lib.mkDefault true;
      routingFeatures = lib.mkDefault "client";
      trustInterface = lib.mkDefault true;
    };
  };

  # Responsiveness/Latency optimization for battery/mobile use
  services.system76-scheduler = {
    enable = lib.mkDefault true;
    useStockConfig = lib.mkDefault true;
    settings = {
      cfsProfiles.enable = true; # Low-latency kernel tuning
      processScheduler = {
        enable = true;
        foregroundBoost.enable = true; # Boost active window
        pipewireBoost.enable = true;   # Enforce audio priorities
      };
    };
  };

  core = {
    boot.silent = lib.mkDefault true;
    nix.gc.automatic = lib.mkDefault true;
    secureboot.enable = lib.mkDefault true;
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
