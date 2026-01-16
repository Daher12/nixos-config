{
  lib,
  config,
  pkgs,
  ...
}:

let
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

  homeWifiMarker = pkgs.writeText "wifi-home-marker" homeWifiContent;

  workWifiContent = ''
    [connection]
    id=WorkWiFi
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

  sops.secrets."wifi_home_psk".restartUnits = lib.mkIf config.features.sops.enable [ "NetworkManager.service" ];
  sops.secrets."wifi_work_psk".restartUnits = lib.mkIf config.features.sops.enable [ "NetworkManager.service" ];

  sops.templates."wifi-home.nmconnection" = lib.mkIf config.features.sops.enable {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
    content = homeWifiContent;
  };

  sops.templates."wifi-work.nmconnection" = lib.mkIf config.features.sops.enable {
    mode = "0600";
    path = "/etc/NetworkManager/system-connections/work-wifi.nmconnection";
    content = workWifiContent;
  };

  systemd.services.NetworkManager.restartTriggers = lib.mkIf config.features.sops.enable [
    homeWifiMarker
    workWifiMarker
  ];

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
