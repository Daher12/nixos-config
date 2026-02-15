# modules/hardware/ryzen-tdp.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.ryzen-tdp;
  toMW = watts: toString (watts * 1000);

  setTdp = pkgs.writeShellApplication {
    name = "set-ryzen-tdp";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.ryzenadj
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      LOCK_FILE=/run/ryzen-tdp.lock

      is_on_ac() {
        for psu in /sys/class/power_supply/*; do
           local type_file="$psu/type"
           local online_file="$psu/online"

           if [ -f "$type_file" ] && [ -f "$online_file" ]; then
              local type
              type=$(cat "$type_file")
              local online
              online=$(cat "$online_file")

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

      exec 9>"$LOCK_FILE"
      flock -w 5 -x 9 || exit 1

      apply_limits
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
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 60;
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 54;
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 95;
      };
    };

    battery = {
      stapm = lib.mkOption {
        type = lib.types.int;
        default = 25;
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 30;
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 25;
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 85;
      };
    };

    watchdogInterval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to re-apply limits";
    };

    settleDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Delay before applying limits after wake";
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
        ConditionPathExistsGlob = "/sys/class/power_supply/*/online";
      };

      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "1s";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.settleDelaySec}";
        ExecStart = lib.getExe setTdp;
        TimeoutStartSec = "10s";
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
      SUBSYSTEM=="power_supply", ACTION=="change", ATTR{online}=="?*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ryzen-tdp-control.service"
    '';
  };
}
