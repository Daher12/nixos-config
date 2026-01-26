{
  lib,
  config,
  ...
}:

let
  # ----------------------------------------------------------------------------
  # WiFi Data (NetworkManager Keyfile Format)
  # ----------------------------------------------------------------------------
  homeWifiContent = ''
    [connection]
    id=HomeWiFi
    uuid=7a3b4c5d-1234-5678-9abc-def012345678
    type=wifi
    autoconnect=true # predictable behavior; avoids relying on NM defaults

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

  workWifiContent = ''
    [connection]
    id=WorkWiFi
    uuid=8b4c5d6e-2345-6789-0bcd-ef1234567890
    type=wifi
    autoconnect=true # predictable behavior; avoids relying on NM defaults

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
in
lib.mkMerge [
  # ----------------------------------------------------------------------------
  # Block 1: Base Configuration
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # Block 2: SOPS Configuration
  # ----------------------------------------------------------------------------
  (lib.mkIf config.features.sops.enable {
    # Safety: ensure the consumer of these secrets is actually enabled.
    assertions = [
      {
        assertion = config.networking.networkmanager.enable or false;
        message = "WiFi nmconnection templates are enabled, but networking.networkmanager.enable is false.";
      }
    ];

    sops = {
      secrets = {
        # Native sops-nix restart handling (superior to restartTriggers on static markers)
        "wifi_home_psk".restartUnits = [ "NetworkManager.service" ];
        "wifi_work_psk".restartUnits = [ "NetworkManager.service" ];
      };

      templates = {
        "wifi-home.nmconnection" = {
          mode = "0600";
          owner = "root"; # explicit: system-connections must be root-owned
          group = "root";
          path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
          content = homeWifiContent;
        };
        "wifi-work.nmconnection" = {
          mode = "0600";
          owner = "root";
          group = "root";
          path = "/etc/NetworkManager/system-connections/work-wifi.nmconnection";
          content = workWifiContent;
        };
      };
    };
  })
]
