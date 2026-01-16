{ lib, config, ... }:

{
  features = {
    bluetooth.enable = lib.mkDefault true;
    power-tlp.enable = lib.mkDefault true;
    zram.enable = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
    kernel.variant = lib.mkDefault "zen";

    vpn.tailscale = {
      enable = lib.mkDefault true;
      routingFeatures = lib.mkDefault "client";
      trustInterface = lib.mkDefault true;
    };

    # NEW: Enable SOPS for all laptops
    sops.enable = true;
  };

  # SOPS Configuration Example
  # --------------------------
  # 1. Define the secret (reads from secrets/hosts/<hostname>.yaml)
  sops.secrets."wifi_psk" = {
    # Restart NM if the underlying secret changes
    restartUnits = [ "NetworkManager.service" ];
  };

  # 2. Template the NetworkManager file
  sops.templates."wifi-home.nmconnection" = {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
    content = ''
      [connection]
      id=HomeWiFi
      uuid=7a3b4c5d-1234-5678-9abc-def012345678
      type=wifi
      
      [wifi]
      ssid=MyHomeNetwork
      mode=infrastructure
      
      [wifi-security]
      key-mgmt=wpa-psk
      psk=${config.sops.placeholder."wifi_psk"}
      
      [ipv4]
      method=auto
      
      [ipv6]
      method=auto
    '';
  };

  services.system76-scheduler = {
    enable = lib.mkDefault true;
    useStockConfig = lib.mkDefault true;
    settings = {
      cfsProfiles.enable = true;
      processScheduler = {
        enable = true;
        foregroundBoost.enable = true;
        pipewireBoost.enable = true;
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
