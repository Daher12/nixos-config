{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.ryzen-tdp;
  toMW = watts: toString (watts * 1000);

  # Refactored script with concurrency locking
  setTdp = pkgs.writeShellApplication {
    name = "set-ryzen-tdp";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.ryzenadj
      pkgs.util-linux # for flock
    ];
    text = ''
      set -euo pipefail

      LOCK_FILE="/run/ryzen-tdp.lock"

      is_on_ac() {
        for psu in /sys/class/power_supply/*; do
           local type_file="$psu/type"
           local online_file="$psu/online"

           if [ -f "$type_file" ] && [ -f "$online_file" ]; then
              local type
              type=$(cat "$type_file")
              local online
              online=$(cat "$online_file")

              # Treat USB as AC only if online (e.g. USB-C PD)
              if [ "$online" = "1" ] && { [ "$type" = "Mains" ] || [ "$type" = "USB" ]; }; then
                 return 0
              fi
           fi
        done
        return 1
      }

      apply_limits() {
        if is_on_ac; then
          echo "Power: AC – applying ${toString cfg.ac.stapm}W STAPM"
          ryzenadj \
            --stapm-limit=${toMW cfg.ac.stapm} \
            --fast-limit=${toMW cfg.ac.fast} \
            --slow-limit=${toMW cfg.ac.slow} \
            --tctl-temp=${toString cfg.ac.temp}
        else
          echo "Power: Battery – applying ${toString cfg.battery.stapm}W STAPM"
          ryzenadj \
            --stapm-limit=${toMW cfg.battery.stapm} \
            --fast-limit=${toMW cfg.battery.fast} \
            --slow-limit=${toMW cfg.battery.slow} \
            --tctl-temp=${toString cfg.battery.temp}
        fi
      }

      # Main execution with exclusive lock to prevent SMU mailbox races
      # (udev and timer events can fire simultaneously)
      {
        flock -w 5 -x 9 # avoid indefinite hangs if a prior run wedges
        apply_limits
      } 9>"$LOCK_FILE"
    '';
  };
in
{
  options.hardware.ryzen-tdp = {
    enable = lib.mkEnableOption "Ryzen TDP control via ryzenadj (AC/Battery profiles)";

    ac = {
      stapm = lib.mkOption {
        type = lib.types.int;
        default = 54;
        description = "Sustained TDP (W)";
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Fast boost TDP (W)";
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 54;
        description = "Slow boost TDP (W)";
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 95;
        description = "Temperature limit (°C)";
      };
    };

    battery = {
      stapm = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Sustained TDP (W)";
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Fast boost TDP (W)";
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Slow boost TDP (W)";
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 85;
        description = "Temperature limit (°C)";
      };
    };

    watchdogInterval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      example = "60s";
      description = "How often to re-apply limits (firmware may reset them)";
    };

    settleDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Delay before applying limits after wake/profile change";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ryzenadj ];

    systemd.services.ryzen-tdp-control = {
      description = "Apply Ryzen TDP limits (AC/Battery)";
      wantedBy = [
        "multi-user.target"
        "post-resume.target"
      ];
      after = [
        "systemd-logind.service"
        "post-resume.target"
      ];

      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 10;
        # Robustness: Don't fail on machines without battery/AC sensors (e.g. Desktops/VMs)
        # Tighten: require at least one readable "online" indicator.
        ConditionPathExistsGlob = "/sys/class/power_supply/*/online";
      };

      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "1s";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.settleDelaySec}";
        ExecStart = lib.getExe setTdp;
      };
    };

    systemd.timers.ryzen-tdp-watchdog = {
      description = "Re-apply Ryzen TDP limits periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.watchdogInterval;
        RandomizedDelaySec = "30s";
        Unit = "ryzen-tdp-control.service";
      };
    };

    services.udev.extraRules = ''
      # Trigger only on power_supply changes (charging/discharging state)
      # ATTR{online} check helps filter some noise, but oneshot service + flock handles the rest.
      SUBSYSTEM=="power_supply", ACTION=="change", ATTR{online}=="?*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ryzen-tdp-control.service"
    '';
  };
}
