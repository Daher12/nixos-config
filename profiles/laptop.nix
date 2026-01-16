{
  lib,
  config,
  pkgs,
  ...
}:

let
  # ============================================================================
  # NETWORK 1: HOME
  # ============================================================================
  homeWifiContent = ''
    [connection]
    id=HomeWiFi
    uuid=7a3b4c5d-1234-5678-9abc-def012345678
    type=wifi

    [wifi]
    ssid=FRITZ!Box G
    mode=infrastructure

    [wifi-security]
    key-mgmt=wpa-psk
    psk=${config.sops.placeholder."wifi_home_psk"}

    [ipv4]
    method=auto
    [ipv6]
    method=auto
  '';

  # Marker for Home (changes if SSID/UUID changes)
  homeWifiMarker = pkgs.writeText "wifi-home-marker" homeWifiContent;

  # ============================================================================
  # NETWORK 2: WORK
  # ============================================================================
  workWifiContent = ''
    [connection]
    id=WorkWiFi
    # Generate a NEW UUID for this connection (run `uuidgen` again)
    uuid=8b4c5d6e-2345-6789-0bcd-ef1234567890
    type=wifi

    [wifi]
    ssid=MyWorkOffice
    mode=infrastructure

    [wifi-security]
    key-mgmt=wpa-psk
    psk=${config.sops.placeholder."wifi_work_psk"}

    [ipv4]
    method=auto
    [ipv6]
    method=auto
  '';

  # Marker for Work
  workWifiMarker = pkgs.writeText "wifi-work-marker" workWifiContent;

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
    sops.enable = lib.mkDefault false;
  };

  # ----------------------------------------------------------------------------
  # SOPS Configuration
  # ----------------------------------------------------------------------------

  # 1. Define Secrets
  sops.secrets."wifi_home_psk".restartUnits = [ "NetworkManager.service" ];
  sops.secrets."wifi_work_psk".restartUnits = [ "NetworkManager.service" ];

  # 2. Define Templates
  sops.templates."wifi-home.nmconnection" = {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
    content = homeWifiContent;
  };

  sops.templates."wifi-work.nmconnection" = {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/work-wifi.nmconnection";
    content = workWifiContent;
  };

  # 3. Drift Detection (Restart NM if EITHER template changes)
  systemd.services.NetworkManager.restartTriggers = [
    homeWifiMarker
    workWifiMarker
  ];

  # ----------------------------------------------------------------------------
  # Other Hardware/System Settings
  # ----------------------------------------------------------------------------
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
    secureboot.enable = lib.mkDefault true;
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
