# NOTE: WiFi UUID options and SOPS templates commented out for now.
# To re-enable:
#   1. Get UUIDs: run `nmcli connection show | grep -i wifi` on each host
#   2. Uncomment the options and SOPS template block below
#   3. Add wifi_home_psk / wifi_work_psk to per-host SOPS secrets
#
# let
#   homeWifiContent = ''
#     [connection]
#     id=HomeWiFi
#     uuid=${config.laptop.homeWifiUuid}
#     type=wifi
#     autoconnect=true
#
#     [wifi]
#     ssid=FRITZ!Box G
#     mode=infrastructure
#
#     [wifi-security]
#     key-mgmt=wpa-psk
#     psk=${config.sops.placeholder."wifi_home_psk"}
#
#     [ipv4]
#     method=auto
#     [ipv6]
#     method=auto
#   '';
#
#   workWifiContent = ''
#     [connection]
#     id=WorkWiFi
#     uuid=${config.laptop.workWifiUuid}
#     type=wifi
#     autoconnect=true
#
#     [wifi]
#     ssid=MyWorkOffice
#     mode=infrastructure
#
#     [wifi-security]
#     key-mgmt=wpa-psk
#     psk=${config.sops.placeholder."wifi_work_psk"}
#
#     [ipv4]
#     method=auto
#     [ipv6]
#     method=auto
#   '';
# in

{ lib, ... }:
{
  # options.laptop = {
  #   homeWifiUuid = lib.mkOption {
  #     type = lib.types.str;
  #     description = "UUID for home WiFi NetworkManager connection";
  #     example = "7a3b4c5d-1234-5678-9abc-def012345678";
  #   };
  #   workWifiUuid = lib.mkOption {
  #     type = lib.types.str;
  #     description = "UUID for work WiFi NetworkManager connection";
  #     example = "8b4c5d6e-2345-6789-0bcd-ef1234567890";
  #   };
  # };

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

  # Uncomment when re-enabling WiFi templates:
  # (lib.mkIf config.features.sops.enable {
  #   assertions = [
  #     {
  #       assertion = config.networking.networkmanager.enable or false;
  #       message = "WiFi nmconnection templates enabled but NetworkManager is disabled";
  #     }
  #   ];
  #
  #   sops = {
  #     secrets = {
  #       "wifi_home_psk" = { };
  #       "wifi_work_psk" = { };
  #     };
  #
  #     templates = {
  #       "wifi-home.nmconnection" = {
  #         mode = "0600";
  #         owner = "root";
  #         group = "root";
  #         path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
  #         content = homeWifiContent;
  #         restartUnits = [ "NetworkManager.service" ];
  #       };
  #       "wifi-work.nmconnection" = {
  #         mode = "0600";
  #         owner = "root";
  #         group = "root";
  #         path = "/etc/NetworkManager/system-connections/work-wifi.nmconnection";
  #         content = workWifiContent;
  #         restartUnits = [ "NetworkManager.service" ];
  #       };
  #     };
  #   };
  # })
}
