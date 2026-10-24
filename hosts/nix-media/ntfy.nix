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

  # Bare unit names: the OnFailure template below is "ntfy-failure@%n"
  # WITHOUT a trailing .service — %n already includes the suffix and systemd
  # appends the template's own, so suffixed entries here used to instantiate
  # ntfy-failure@<unit>.service.service.
  criticalServices = [
    "docker-jellyfin"
    "docker-audiobookshelf"
    "docker-cadvisor"
    "docker-network-jellyfin"
    "docker-image-refresh"
    "nixos-upgrade"
  ];

  failureServices = criticalServices;

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

  systemd = {
    services =
      (lib.genAttrs failureServices (_: {
        unitConfig.OnFailure = "ntfy-failure@%n";
      }))
      // {
        "ntfy-failure@" = {
          description = "Notify on %i failure";
          serviceConfig = {
            Type = "oneshot";
            ExecStart =
              let
                # Wrapper that waits for transient failures to settle before notifying.
                # Handles false positives during nixos-rebuild switch when Docker
                # services briefly enter failed state due to restart race conditions.
                notifyScript = pkgs.writeShellScript "ntfy-failure-notify" ''
                  set -euo pipefail
                  SERVICE="$1"

                  # Wait for transient failures to settle (rebuild switches, etc.)
                  sleep 60

                  # Only notify if the service is still failed after the delay.
                  # is-failed alone is NOT enough: units with Restart=on-failure
                  # (e.g. nixos-upgrade, 1h) sit in "activating (auto-restart)"
                  # after a failed run, where is-failed is FALSE — found by the
                  # nix-media-upgrade-pipeline VM test; without the Result
                  # probe, upgrade failures never notified. Result keeps the
                  # last attempt's outcome, so a transient failure that already
                  # restarted clean reads "success" and stays silent.
                  if systemctl is-failed --quiet "$SERVICE" \
                     || [ "$(systemctl show "$SERVICE" -p Result --value)" != "success" ]; then
                    ${ntfySend}/bin/ntfy-send urgent rotating_light,skull "Failed: $SERVICE" "Service $SERVICE failed on ${hostname}"
                  fi
                '';
              in
              "${notifyScript} %i";
          };
        };

        ntfy-boot = {
          description = "Notify on system boot";
          wantedBy = [ "multi-user.target" ];
          # No sops ordering needed: this sops-nix version renders secrets via
          # activation scripts (no sops-nix.service unit exists), which run
          # before any multi-user service.
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
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

        # Dead-man's switch: one low-priority "alive" push per day. Delivery
        # is best-effort (ntfy-send exits 0 on curl failure and skips on a
        # missing secret), so the actionable signal is the ABSENCE of the
        # ping — if the phone stays quiet for a day, go look.
        ntfy-heartbeat = {
          description = "Daily alive ping via ntfy";
          path = [ pkgs.coreutils ];
          serviceConfig.Type = "oneshot";
          script = ''
            ${ntfySend}/bin/ntfy-send min heartbeat \
              "Heartbeat" \
              "${hostname} alive at $(date '+%Y-%m-%d %H:%M')"
          '';
        };
      };

    timers.ntfy-heartbeat = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    tmpfiles.rules = [
      "d /var/log/smartd 0750 root root - -"
    ];
  };

  services.smartd = {
    enable = true;
    notifications = {
      x11.enable = false;
      wall.enable = false;
      mail.enable = false;
    };
    # -A and --attributelog are the same option (short/long); only ever pass
    # one — a second would silently override the first.
    extraOptions = [ "-A /var/log/smartd/" ];
    defaults.monitored = "-a -o on -s (S/../.././02|L/../01/./03) -W 4,45,55 -m <nomailer> -M exec ${smartdNotify}";
  };
}
