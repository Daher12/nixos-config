{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.ryzen-tdp;
  toMW = watts: toString (watts * 1000);
in
{
  options.services.ryzen-tdp = {
    enable = mkEnableOption "Ryzen TDP control via ryzenadj (AC/Battery profiles)";

    ac = {
      stapm = mkOption { type = types.int; default = 54; };
      fast  = mkOption { type = types.int; default = 60; };
      slow  = mkOption { type = types.int; default = 54; };
      temp  = mkOption { type = types.int; default = 95; };
    };

    battery = {
      stapm = mkOption { type = types.int; default = 25; };
      fast  = mkOption { type = types.int; default = 30; };
      slow  = mkOption { type = types.int; default = 25; };
      temp  = mkOption { type = types.int; default = 85; };
    };

    # Firmware sometimes resets limits; re-apply periodically.
    watchdogInterval = mkOption {
      type = types.str;
      default = "5min";
      example = "60s";
      description = "How often to re-apply limits via a systemd timer.";
    };

    settleDelaySec = mkOption {
      type = types.int;
      default = 2;
      description = "Delay before applying limits (helps after wake/profile transitions).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ryzenadj ];

    systemd.services.ryzen-tdp-control = {
      description = "Apply Ryzen TDP limits (AC/Battery)";
      wantedBy = [ "multi-user.target" "post-resume.target" ];
      after = [ "systemd-logind.service" "post-resume.target" ];

      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 10;
      };

      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "1s";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.settleDelaySec}";

        ExecStart =
          let
            app = pkgs.writeShellApplication {
              name = "set-ryzen-tdp";
              runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.ryzenadj ];
              text = ''
                set -euo pipefail

                ON_AC=0
                for psu in /sys/class/power_supply/*; do
                  if [ -f "$psu/type" ] && [ -f "$psu/online" ]; then
                    TYPE="$(cat "$psu/type" || true)"
                    ONLINE="$(cat "$psu/online" || echo 0)"
                    if echo "$TYPE" | grep -qE "Mains|USB_PD"; then
                      if [ "$ONLINE" -eq 1 ]; then
                        ON_AC=1
                        break
                      fi
                    fi
                  fi
                done

                if [ "$ON_AC" -eq 1 ]; then
                  echo "Power: AC — applying ${toString cfg.ac.stapm}W STAPM"
                  ryzenadj \
                    --stapm-limit=${toMW cfg.ac.stapm} \
                    --fast-limit=${toMW cfg.ac.fast} \
                    --slow-limit=${toMW cfg.ac.slow} \
                    --tctl-temp=${toString cfg.ac.temp}
                else
                  echo "Power: Battery — applying ${toString cfg.battery.stapm}W STAPM"
                  ryzenadj \
                    --stapm-limit=${toMW cfg.battery.stapm} \
                    --fast-limit=${toMW cfg.battery.fast} \
                    --slow-limit=${toMW cfg.battery.slow} \
                    --tctl-temp=${toString cfg.battery.temp}
                fi
              '';
            };
          in
          "${app}/bin/set-ryzen-tdp";
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

    # Udev -> systemd-native triggering (avoid RUN+=systemctl)
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ryzen-tdp-control.service"
    '';
  };
}

