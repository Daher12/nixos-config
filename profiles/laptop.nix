{ lib, ... }:

{
  features = {
    bluetooth.enable = lib.mkDefault true;
    power-tlp.enable = lib.mkDefault true;
    zram.enable = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
    kernel.variant = lib.mkDefault "zen";
    oomd.enable = lib.mkDefault true;
    secureboot.enable = lib.mkDefault true;

    vpn.tailscale = {
      enable = lib.mkDefault true;
      routingFeatures = lib.mkDefault "client";
      trustInterface = lib.mkDefault true;
    };

    sops.enable = lib.mkDefault false;
  };

  services.system76-scheduler = {
    enable = lib.mkDefault true;
    useStockConfig = lib.mkDefault true;
    settings.cfsProfiles.enable = true;
    settings.processScheduler = {
      enable = true;
      foregroundBoost.enable = true;
      pipewireBoost.enable = true;
    };
  };

  core = {
    boot.silent = lib.mkDefault true;
    nix.gc.automatic = lib.mkDefault true;
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

}
