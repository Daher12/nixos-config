# hosts/nix-media/maintenance.nix
{ pkgs, ... }:

{
  system.autoUpgrade = {
    enable = true;
    dates = "05:00";
    operation = "boot";
    flake = "github:daher12/nixos-config#nix-media";
    randomizedDelaySec = "45min";
    flags = [ "-L" ];
  };

  systemd.services.biweekly-reboot = {
    description = "Reboot into staged generation if idle";
    after = [ "network.target" ];
    wants = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
      PrivateTmp = true;
    };

    path = with pkgs; [
      coreutils
      systemd
      procps
    ];

    script = ''
      set -euo pipefail

      # Idempotency check
      CURRENT=$(readlink -f /run/current-system || echo "")
      NEXT=$(readlink -f /nix/var/nix/profiles/system || echo "")

      if [ -z "$CURRENT" ] || [ -z "$NEXT" ]; then
        echo "ERROR: Cannot resolve system profiles"
        exit 1
      fi

      if [ "$CURRENT" = "$NEXT" ]; then
        echo "Already on latest generation"
        exit 0
      fi

      # Verify upgrade succeeded
      if systemctl is-failed nixos-upgrade.service >/dev/null 2>&1; then
        echo "Last upgrade failed - aborting reboot"
        exit 1
      fi

      # Activity checks
      if pgrep -x "ffmpeg" >/dev/null 2>&1 || pgrep -x "HandBrakeCLI" >/dev/null 2>&1; then
        echo "Transcoding active - skipping reboot"
        exit 0
      fi

      LOAD=$(awk '{print int($1)}' /proc/loadavg)
      if [ "$LOAD" -gt 2 ]; then
        echo "High load: $LOAD - skipping reboot"
        exit 0
      fi

      # Uptime guard (prevent reboot loops)
      UPTIME_S=$(cut -d. -f1 /proc/uptime)
      if [ "$UPTIME_S" -lt 3600 ]; then
        echo "System recently booted - skipping reboot"
        exit 0
      fi

      echo "Applying staged update: $NEXT"
      shutdown -r +1 "NixOS update reboot"
    '';
  };

  systemd.timers.biweekly-reboot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-1,15 07:30";
      Persistent = true;
    };
  };
}
