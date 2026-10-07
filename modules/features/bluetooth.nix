{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.bluetooth;
in
{
  options.features.bluetooth = {
    enable = lib.mkEnableOption "Bluetooth support";
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
      };
    };

    # BlueZ refuses every NEW pairing unless an agent answers the SSP
    # confirmation/passkey request. 2026-10-06 journal: 13 failed pair
    # attempts via the lucid BT panel — bluetoothd "No agent available for
    # request type 2" and quickshell "Failed to pair: Authentication
    # Failed" line up to the second. quickshell 0.3.1 has no
    # AgentManager/RegisterAgent API at all and nothing else registers an
    # agent; already-paired devices keep working off cached link keys.
    # bt-agent with NoInputNoOutput makes BlueZ use JustWorks
    # (auto-accept, no passkey UI) — no MITM protection during pairing,
    # accepted for a personal laptop.
    systemd.services.bt-agent = {
      description = "Headless BlueZ pairing agent";
      after = [ "bluetooth.service" ];
      partOf = [ "bluetooth.service" ];
      # bluetooth.target does not exist on this host (verified 2026-10-06)
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
