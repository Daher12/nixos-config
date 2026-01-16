{ lib, config, pkgs, ... }:

let
  # 1. Define the Template Content
  # We separate this string so we can use it for both the sops template AND the drift trigger.
  wifiContent = ''
    [connection]
    id=HomeWiFi
    # Run `uuidgen` in your terminal and paste the result here
    uuid=7a3b4c5d-1234-5678-9abc-def012345678
    type=wifi
    
    [wifi]
    ssid=MyHomeNetwork
    mode=infrastructure
    
    [wifi-security]
    key-mgmt=wpa-psk
    # This placeholder is replaced by sops-nix during activation
    psk=${config.sops.placeholder."wifi_psk"}
    
    [ipv4]
    method=auto
    
    [ipv6]
    method=auto
  '';

  # 2. Create the Marker (Drift Detection)
  # optimization: pkgs.writeText produces a unique store path that changes ONLY if 'text' changes.
  wifiTemplateMarker = pkgs.writeText "wifi-template-marker" wifiContent;
in
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

    # Enable SOPS for all laptops
    sops.enable = true;
  };

  # 3. Secret Definition (Restarts NM on password rotation)
  sops.secrets."wifi_psk" = {
    restartUnits = [ "NetworkManager.service" ];
  };

  # 4. Template Definition
  sops.templates."wifi-home.nmconnection" = {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
    content = wifiContent;
  };

  # 5. Explicit Trigger for Template Drift
  # If you change the SSID (but not the secret), the 'wifiContent' string changes,
  # which changes the 'wifiTemplateMarker' store path, which triggers the restart.
  systemd.services.NetworkManager.restartTriggers = [ wifiTemplateMarker ];

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
