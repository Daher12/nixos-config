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

    # Rembrandt note (2026-11-25): --stapm-limit is accepted but does not
    # stick on this SoC. Upstream's support matrix marks it "no effect", and
    # the on-device check agrees — the `ryzenadj --info` table logged by the
    # service still shows STAPM LIMIT 59.967 W right after a 50 W write, while
    # fast/slow/Tctl read back exactly as set. The knobs that take effect are
    # SLOW (sustained), FAST (burst) and Tctl. The stapm options are kept for
    # portability and are still written (harmless); the log lines name the
    # effective caps.
    #
    # On AC the firmware's skin-temperature policy governs sustained power
    # anyway (measured ~26-29 W with slow limits of 40/50/54 W alike), so the
    # configured slow limit only binds on battery, where it sits below that.
    ac = {
      stapm = lib.mkOption {
        type = lib.types.int;
        default = 54;
        description = "AC STAPM limit in watts (inert on Rembrandt; the slow limit is the real sustained cap)";
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "AC FAST limit in watts (short boost)";
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 54;
        description = "AC SLOW limit in watts (long boost)";
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 95;
        description = "AC Tctl temperature limit in °C";
      };
    };

    battery = {
      stapm = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Battery STAPM limit in watts (inert on Rembrandt; the slow limit is the real sustained cap)";
      };
      fast = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Battery FAST limit in watts (short boost)";
      };
      slow = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Battery SLOW limit in watts (long boost)";
      };
      temp = lib.mkOption {
        type = lib.types.int;
        default = 85;
        description = "Battery Tctl temperature limit in °C";
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
              echo "Power: AC — caps fast ${toString cfg.ac.fast}W / slow ${toString cfg.ac.slow}W (sustained), Tctl ${toString cfg.ac.temp}C (stapm write inert on Rembrandt)"
              ryzenadj \
                --stapm-limit=${toMW cfg.ac.stapm} \
                --fast-limit=${toMW cfg.ac.fast} \
                --slow-limit=${toMW cfg.ac.slow} \
                --tctl-temp=${toString cfg.ac.temp}
            else
              echo "Power: Battery — caps fast ${toString cfg.battery.fast}W / slow ${toString cfg.battery.slow}W (sustained), Tctl ${toString cfg.battery.temp}C (stapm write inert on Rembrandt)"
              ryzenadj \
                --stapm-limit=${toMW cfg.battery.stapm} \
                --fast-limit=${toMW cfg.battery.fast} \
                --slow-limit=${toMW cfg.battery.slow} \
                --tctl-temp=${toString cfg.battery.temp}
            fi
            # Applied-limit ground truth into the journal (SMU fw version,
            # power metrics) — makes watchdog runs auditable against drift.
            ryzenadj --info || true
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
