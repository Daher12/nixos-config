{
  pkgs,
  mainUser,
  ...
}:

{
  system.autoUpgrade = {
    enable = true;
    dates = "05:00";
    operation = "boot";
    flake = "path:/home/dk/nixos-config#nix-media";
    randomizedDelaySec = "45min";
    flags = [ "-L" ];
  };

  systemd = {
    services = {
      nixos-upgrade = {
        # The upstream nixos-upgrade script performs NO git operations: with
        # a path:/ flake it rebuilds whatever the local clone contains, so
        # without this pull the daily 05:00 run re-stages a static tree
        # forever and the CI's weekly lock bump never reaches this host
        # (verified against the nixpkgs auto-upgrade module 2026-10-19).
        # Runs as ${mainUser} because the clone is user-owned (root git gets
        # the dubious-ownership refusal; runuser -u flips the euid so the
        # safe.directory check passes). --ff-only aborts on a diverged clone
        # instead of merging, and GIT_TERMINAL_PROMPT=0 makes any credential
        # need a hard failure — a stuck unit would block the reboot chain.
        # Any pull failure fails the unit → hourly restart + ntfy push
        # (OnFailure already wired in ntfy.nix) and weekly-reboot aborts.
        environment.GIT_TERMINAL_PROMPT = "0";
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "1h";
          TimeoutStartSec = "30min";
          ExecStartPre = "${pkgs.util-linux}/bin/runuser -u ${mainUser} -- ${pkgs.git}/bin/git -C /home/${mainUser}/nixos-config pull --ff-only";
        };
      };

      weekly-reboot = {
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
          gawk
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

          # Verify upgrade succeeded. is-failed alone is NOT enough: with
          # Restart=on-failure (1h) a failed run sits in "activating
          # (auto-restart)" where is-failed is FALSE — the same trap the
          # nix-media-pipeline VM test caught in ntfy.nix's notifier. Result
          # keeps the last attempt's outcome; the ActiveState probe also
          # aborts while a retry is actually running (an hourly restart can
          # still be mid-build at Sun 07:30 — a reboot would kill it).
          if [ "$(systemctl show nixos-upgrade.service -p Result --value)" != "success" ] \
            || [ "$(systemctl show nixos-upgrade.service -p ActiveState --value)" != "inactive" ]; then
            echo "Last upgrade failed or is still running - aborting reboot"
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
    };

    timers.weekly-reboot = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Fires every Sunday; idempotency check in script skips if no staged update
        OnCalendar = "Sun 07:30";
        Persistent = true;
      };
    };
  };
}
