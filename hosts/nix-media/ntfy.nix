{
  config,
  pkgs,
  lib,
  ...
}:

# Push Notifications via ntfy (Secured with SOPS)
#
# Usage: ntfy-send <priority> <tags> <title> <message>

let
  ntfyServer = "https://ntfy.sh";
  hostname = config.networking.hostName;

  # Secrets: Define the topic secret
  secretName = "ntfy_topic";

  # List of systemd services to monitor for failure
  failureServices = [
    "docker-jellyfin"
    "docker-audiobookshelf"
    "docker-cadvisor"
    "docker-network-jellyfin"
    "nixos-upgrade"
    "docker-image-refresh"
  ];

  # The main notification script
  ntfySend = pkgs.writeShellScriptBin "ntfy-send" ''
    set -euo pipefail

    # 1. Load Topic from Secret
    if [ ! -f "${config.sops.secrets.${secretName}.path}" ]; then
      ${pkgs.util-linux}/bin/logger -t ntfy-send "Error: Secret ${secretName} not found"
      exit 1
    fi
    NTFY_TOPIC=$(cat "${config.sops.secrets.${secretName}.path}")

    # 2. Parse Arguments
    PRIORITY="''${1:-default}"
    TAGS="''${2:-}"
    TITLE="''${3:-Notification}"
    MESSAGE="''${4:-}"

    # 3. Send Notification
    ${pkgs.curl}/bin/curl -sf --max-time 10 --retry 2 --retry-delay 5 \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -d "$MESSAGE" \
      "${ntfyServer}/$NTFY_TOPIC" \
      || ${pkgs.util-linux}/bin/logger -t ntfy-send "Failed to send: $TITLE"
  '';

  # Wrapper for smartd (Calls the main script)
  smartdNotify = pkgs.writeShellScript "smartd-ntfy" ''
    ${ntfySend}/bin/ntfy-send urgent warning,hard_drive \
      "Disk Error: $SMARTD_DEVICE" \
      "SMART error on ${hostname}: $SMARTD_MESSAGE"
  '';
in
{
  # --- Secret Definition ---
  sops.secrets.${secretName} = {
    owner = "root";
    group = "root";
    mode = "0400";
    # Restart services if the topic changes
    restartUnits = [ "ntfy-boot.service" ];
  };

  environment.systemPackages = [ ntfySend ];

  # --- Failure Hooks ---
  # Automatically generates OnFailure handlers for critical services
  # FIX: Replaced unused 'name' with '_'
  systemd.services =
    (lib.genAttrs failureServices (_: {
      unitConfig.OnFailure = "ntfy-failure@%n.service";
    }))
    // {

      # Template: Notification logic
      "ntfy-failure@" = {
        description = "Notify on %i failure";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${ntfySend}/bin/ntfy-send urgent rotating_light,skull \"Failed: %i\" \"Service %i failed on ${hostname}\"";
        };
      };

      # Boot Notification
      ntfy-boot = {
        description = "Notify on system boot";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${ntfySend}/bin/ntfy-send default computer,white_check_mark \"System Boot\" \"${hostname} started successfully\"";
        };
      };
    };

  # --- SMART Disk Monitoring ---
  services.smartd = {
    notifications = {
      x11.enable = false;
      wall.enable = true; # Console broadcast
      mail.enable = false;
    };
    extraOptions = [
      "-A /var/log/smartd/"
      "--attributelog=-"
    ];
    defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03) -W 4,45,55 -m @${smartdNotify}";
  };
}
