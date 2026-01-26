{
  config,
  pkgs,
  lib,
  ...
}:

# Push Notifications via ntfy (Secured with SOPS)
# Usage: ntfy-send <priority> <tags> <title> <message>

let
  ntfyServer = "https://ntfy.sh";
  hostname = config.networking.hostName;

  # Secrets: Define the topic secret
  secretName = "ntfy_topic";

  # Critical services to monitor
  criticalServices = [
    "docker-jellyfin.service"
    "docker-audiobookshelf.service"
    "docker-cadvisor.service"
    "docker-network-jellyfin.service"
    "nixos-upgrade.service"
    "docker-image-refresh.service"
  ];

  failureServices = map (lib.removeSuffix ".service") criticalServices;

  # The main notification script (Reads topic from SOPS secret)
  ntfySend = pkgs.writeShellScriptBin "ntfy-send" ''
    set -euo pipefail

    # 1. Load Topic from Secret (Fail-Soft)
    if [ ! -f "${config.sops.secrets.${secretName}.path}" ]; then
      ${pkgs.util-linux}/bin/logger -t ntfy-send "Warning: Secret ${secretName} not found. Skipping notification."
      # Exit 0 to prevent the notification service itself from entering 'failed' state
      exit 0
    fi

    # HARDENING: Strip newlines which SOPS/editors might insert
    NTFY_TOPIC=$(tr -d '\n' < "${config.sops.secrets.${secretName}.path}")

    # 2. Parse Arguments
    PRIORITY="''${1:-default}"
    TAGS="''${2:-}"
    TITLE="''${3:-Notification}"
    MESSAGE="''${4:-}"

    # 3. Send Notification
    # HARDENING: Connect timeout prevents hangs; Fail-Soft logic logs errors but doesn't crash script
    ${pkgs.curl}/bin/curl -sf --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 5 \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -d "$MESSAGE" \
      "${ntfyServer}/$NTFY_TOPIC" \
      || ${pkgs.util-linux}/bin/logger -t ntfy-send "Failed to send: $TITLE"
  '';

  # Wrapper for smartd
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
  systemd.services =
    (lib.genAttrs failureServices (_: {
      unitConfig.OnFailure = "ntfy-failure@%n.service";
    }))
    // {
      # Template: Notification logic
      "ntfy-failure@" = {
        description = "Notify on %i failure";
        serviceConfig.Type = "oneshot";
        # ROBUSTNESS: Use script block for safer quoting than ExecStart
        script = ''
          ${ntfySend}/bin/ntfy-send urgent rotating_light,skull \
            "Failed: %i" \
            "Service %i failed on ${hostname}"
        '';
      };

      # Boot Notification
      ntfy-boot = {
        description = "Notify on system boot";
        wantedBy = [ "multi-user.target" ];
        # Best-effort ordering; script self-checks for secret existence
        after = [
          "network-online.target"
          "sops-nix.service"
        ];
        wants = [
          "network-online.target"
          "sops-nix.service"
        ];
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

  # --- SMART Disk Monitoring ---
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

  # HARDENING: Ensure smartd log directory exists
  systemd.tmpfiles.rules = [
    "d /var/log/smartd 0750 root root - -"
  ];
}
