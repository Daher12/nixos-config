{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.ryzen-tdp;
  toMW = watts: toString (watts * 1000);
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

  config = lib.mkIf cfg.enable (
    let
      setTdp = pkgs.writeShellApplication {
        name = "set-ryzen-tdp";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.is-on-ac
          pkgs.ryzenadj
          pkgs.util-linux
        ];
        text = ''
          set -euo pipefail

          LOCK_FILE=/run/ryzen-tdp.lock

          apply_limits() {
            if is-on-ac; then
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
          # Rate limiting disabled: plug/unplug transitions emit several
          # power_supply events in quick succession and each start costs
          # settleDelaySec — the default 5-per-10s burst limit could drop
          # the final state for up to a watchdog interval after an AC flip.
          StartLimitBurst = 0;
          StartLimitIntervalSec = 0;
          ConditionPathExistsGlob = "/sys/class/power_supply/*/online";
        };

        serviceConfig = {
          Type = "oneshot";
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
    }
  );
}
