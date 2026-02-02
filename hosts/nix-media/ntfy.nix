{
  config,
  pkgs,
  lib,
  ...
}:

let
  ntfyServer = "https://ntfy.sh";
  hostname = config.networking.hostName;
  secretName = "ntfy_topic";

  criticalServices = [
    "docker-jellyfin.service"
    "docker-audiobookshelf.service"
    "docker-cadvisor.service"
    "docker-network-jellyfin.service"
    "nixos-upgrade.service"
    "docker-image-refresh.service"
  ];

  failureServices = map (lib.removeSuffix ".service") criticalServices;

  ntfySend = pkgs.writeShellScriptBin "ntfy-send" ''
    set -euo pipefail

    if [ ! -f "${config.sops.secrets.${secretName}.path}" ]; then
      ${pkgs.util-linux}/bin/logger -t ntfy-send "Warning: Secret ${secretName} not found. Skipping notification."
      exit 0
    fi

    NTFY_TOPIC=$(tr -d '\n' < "${config.sops.secrets.${secretName}.path}")
    PRIORITY="''${1:-default}"
    TAGS="''${2:-}"
    TITLE="''${3:-Notification}"
    MESSAGE="''${4:-}"

    ${pkgs.curl}/bin/curl -sf --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 5 \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      --data-raw "$MESSAGE" \
      "${ntfyServer}/$NTFY_TOPIC" \
      || ${pkgs.util-linux}/bin/logger -t ntfy-send "Failed to send: $TITLE"
  '';

  smartdNotify = pkgs.writeShellScript "smartd-ntfy" ''
    ${ntfySend}/bin/ntfy-send urgent warning,hard_drive \
      "Disk Error: $SMARTD_DEVICE" \
      "SMART error on ${hostname}: $SMARTD_MESSAGE"
  '';
in
{
  sops.secrets.${secretName} = {
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [ "ntfy-boot.service" ];
  };

  environment.systemPackages = [ ntfySend ];

  systemd.services =
    (lib.genAttrs failureServices (_: {
      unitConfig.OnFailure = "ntfy-failure@%n.service";
    }))
    // {
      "ntfy-failure@" = {
        description = "Notify on %i failure";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''${ntfySend}/bin/ntfy-send urgent rotating_light,skull "Failed: %i" "Service %i failed on ${hostname}"'';
        };
      };

      ntfy-boot = {
        description = "Notify on system boot";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "sops-nix.service" ];
        wants = [ "network-online.target" "sops-nix.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${ntfySend}/bin/ntfy-send default computer,white_check_mark \
            "System Boot" \
            "${hostname} started successfully"
        '';
      };
    };

  services.smartd = {
    enable = true;
    notifications = {
      x11.enable = false;
      wall.enable = true;
      mail.enable = false;
    };
    extraOptions = [
      "-A /var/log/smartd/"
      "--attributelog=-"
    ];
    defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03) -W 4,45,55 -m @${smartdNotify}";
  };

  systemd.tmpfiles.rules = [
    "d /var/log/smartd 0750 root root - -"
  ];
}
