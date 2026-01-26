{ pkgs, ... }:

{
  # ---------------------------------------------------------------------------
  # Auto-Upgrade Strategy (Immutable System)
  # ---------------------------------------------------------------------------
  system.autoUpgrade = {
    enable = true;
    dates = "05:00";
    operation = "boot"; # Stage only. Do not switch.
    flake = "github:daher12/nixos-config#nix-media";
    randomizedDelaySec = "45min";
    # Print build logs to the journal for post-mortem analysis
    flags = [ "-L" ];
  };

  # ---------------------------------------------------------------------------
  # Smart Reboot Logic
  # ---------------------------------------------------------------------------
  systemd.services.weekly-maintenance-reboot = {
    description = "Weekly reboot into latest NixOS generation with safety checks";

    # Optimization: We only check localhost, so we don't need to wait for WAN
    # after = [ "network-online.target" ]; 
    # wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # Bound runtime; avoid stuck oneshots holding state
      TimeoutStartSec = "2min";

      # Basic hardening; keep it boring (no aggressive sandboxing that breaks shutdown)
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      # Use a private runtime directory instead of /tmp for security/cleanliness
      RuntimeDirectory = "weekly-maintenance-reboot";
      RuntimeDirectoryMode = "0700";
    };

    path = with pkgs; [
      curl
      jq
      coreutils
      systemd
    ];

    script = ''
      set -euo pipefail

      # -----------------------------------------------------------------------
      # 1. Safety Checks (Activity Detection)
      # -----------------------------------------------------------------------

      # Check Jellyfin (Port 8096)
      TMP="$RUNTIME_DIRECTORY/jf-sessions.json"

      # Fail-closed: If we cannot explicitly confirm the server is idle, we assume it is busy.
      # Added --connect-timeout 2 to prevent SYN hangs.
      if ! curl -sf --connect-timeout 2 --max-time 5 http://127.0.0.1:8096/Sessions -o "$TMP"; then
         echo "Unable to query Jellyfin sessions (curl failed/auth required). Skipping reboot (fail-closed)."
         exit 0
      fi

      # Guard against parse errors (e.g. invalid JSON, 502 HTML response)
      if ! jq -e '.' < "$TMP" >/dev/null; then
         echo "Unable to parse Jellyfin sessions JSON. Skipping reboot (fail-closed)."
         exit 0
      fi

      # Fail-closed on unexpected schema: require an array.
      if ! jq -e 'type == "array"' < "$TMP" >/dev/null; then
         echo "Unexpected Jellyfin sessions payload type (not array). Skipping reboot (fail-closed)."
         exit 0
      fi

      if jq -e 'length > 0' < "$TMP" >/dev/null; then
         echo "Active Jellyfin sessions detected. Aborting maintenance reboot."
         exit 0
      fi

      # -----------------------------------------------------------------------
      # 1b. Uptime Guard (Prevent "Persistent=true" loops)
      # -----------------------------------------------------------------------
      # If the machine was just turned on (e.g. Monday morning after being off),
      # prevent the persistent timer from rebooting it immediately.
      UPTIME_S=$(cut -d. -f1 /proc/uptime)
      if [ "$UPTIME_S" -lt 3600 ]; then
        echo "Uptime < 1h (timer catch-up scenario). Skipping reboot."
        exit 0
      fi

      # -----------------------------------------------------------------------
      # 2. Idempotency Check (Robust)
      # -----------------------------------------------------------------------
      # Use || true to prevent script abortion if links are missing
      CURRENT=$(readlink -f /run/current-system || true)
      NEXT=$(readlink -f /nix/var/nix/profiles/system || true)

      if [ -z "$CURRENT" ] || [ -z "$NEXT" ]; then
        echo "Unable to resolve system profile links. Skipping reboot (fail-closed)."
        exit 0
      fi

      if [ "$CURRENT" = "$NEXT" ]; then
        echo "System is already running the latest generation. Skipping reboot."
        exit 0
      fi

      # -----------------------------------------------------------------------
      # 3. Validation & Execution
      # -----------------------------------------------------------------------
      # Validate that the upgrade infrastructure actually exists
      if ! systemctl cat nixos-upgrade.service >/dev/null 2>&1; then
        echo "nixos-upgrade.service not found. Skipping reboot (cannot validate upgrade status)."
        exit 0
      fi

      # Ensure we don't reboot while a slow upgrade is still building/downloading
      if systemctl --quiet is-active nixos-upgrade.service; then
        echo "nixos-upgrade.service is still active (build in progress). Skipping reboot."
        exit 0
      fi

      # Check if the upgrade failed
      if systemctl --quiet is-failed nixos-upgrade.service; then
        echo "nixos-upgrade.service failed. Skipping reboot to prevent loading bad state."
        exit 0
      fi

      echo "Safety checks passed. Rebooting into staged generation."
      shutdown -r +1 "Applying weekly NixOS updates"
    '';
  };

  systemd.timers.weekly-maintenance-reboot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 07:30 ensures autoUpgrade (05:00 + 45m random) has completed.
      OnCalendar = "Sun 07:30";
      Persistent = true;
    };
  };
}
