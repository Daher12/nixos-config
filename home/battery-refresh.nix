{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.battery-refresh;

  # The panel definition is shared by every session: hosts set
  # desktop.hyprland.monitors even on GNOME- and niri-only attrs, so the
  # first entry with an explicit WxH@Hz mode is the internal panel in any
  # session.
  monitors = config.desktop.hyprland.monitors;
  withRate = lib.filter (m: builtins.match ".+@[0-9.]+" m.mode != null) monitors;

  panel = builtins.head withRate;
  modeParts = builtins.match "(.+)@([0-9.]+)" panel.mode;
  # Resolution part of the panel mode ("3072x1920@120" -> "3072x1920").
  wxh = lib.head modeParts;
  batMode = "${wxh}@${toString cfg.refreshRate}";

  posParts = builtins.match "(-?[0-9]+)x(-?[0-9]+)" panel.position;
  posX = if posParts != null then lib.head posParts else "0";
  posY = if posParts != null then lib.elemAt posParts 1 else "0";

  # Integer part of the configured rate: both probes report rounded
  # integers, so `want` must be integer-shaped too.
  panelHz = lib.head (builtins.match "([0-9]+)(\\.[0-9]+)?" (lib.elemAt modeParts 1));

  # Shared loop logic: re-derive (power, lid[, ext]) every pollInterval
  # seconds, then compare the panel's ACTUAL refresh rate (probeFn) against
  # the desired one for the power state, applying the mode whenever they
  # differ and the guards pass. The comparison is against reality, not
  # remembered state, so anything that resets the panel behind the daemon's
  # back — hibernate resume (the compositor re-applies its configured mode
  # on thaw), a config reload, a manual mode switch — self-heals within one
  # poll instead of silently sticking at the wrong rate.
  #
  # Guards (deliberate, both of them):
  #   - lid closed      -> never touch the panel (the lid switch disabled
  #                        it; applying to a disabled panel is at best a
  #                        no-op and at worst re-enables it — reload-on-open
  #                        restores the configured mode and the next poll
  #                        re-lowers it)
  #   - external output connected (GNOME only) -> never touch the panel
  #                        (`set -L` replaces the whole monitor configuration)
  #
  # probeFn must print the panel's current integer Hz and return non-zero
  # when it can't (compositor socket races at session start, session
  # teardown); applyFn must return non-zero on failure. A failed probe or
  # apply simply retries on the next poll, when the actual rate still
  # differs. acMode/batMode are the mode strings handed to applyFn — each
  # backend spells them in its own compositor's grammar.
  daemonText = probeFn: applyFn: extGuard: acMode: batMode: ''
    lid_open() {
      local f
      for f in /proc/acpi/button/lid/*/state; do
        [ -f "$f" ] || continue
        grep -q closed "$f" && return 1
      done
      return 0
    }

    ${lib.optionalString extGuard ''
      ext_connected() {
        local f
        for f in /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status; do
          [ -f "$f" ] || continue
          grep -qx connected "$f" && return 0
        done
        return 1
      }
    ''}

    current_hz() {
      ${probeFn}
    }

    apply() {
      ${applyFn}
    }

    can_apply() {
      [ "$lid" = open ] || return 1
      ${lib.optionalString extGuard ''
        [ "$ext" = none ] || return 1
      ''}
      return 0
    }

    while true; do
      if is-on-ac; then pwr=ac; else pwr=bat; fi
      if lid_open; then lid=open; else lid=closed; fi
      ${lib.optionalString extGuard ''
        if ext_connected; then ext=ext; else ext=none; fi
      ''}
      if can_apply; then
        if [ "$pwr" = ac ]; then
          want='${panelHz}'
          mode='${acMode}'
        else
          want='${toString cfg.refreshRate}'
          mode='${batMode}'
        fi
        have=$(current_hz) || have=""
        if [ -n "$have" ] && [ "$have" != "$want" ]; then
          echo "battery-refresh: ${panel.output} at ''${have} Hz, restoring ''${want} Hz (''${pwr})" >&2
          apply "$mode" || true
        fi
      fi
      sleep ${toString cfg.pollInterval}
    done
  '';

  # Hyprland session: hyprctl talks to the compositor (uwsm imports
  # HYPRLAND_INSTANCE_SIGNATURE/XDG_RUNTIME_DIR into the user manager, where
  # this runs as a service). `hyprctl eval` instead of `keyword monitor`:
  # see home/hyprland.nix (0.55's Lua parser silently ignores keyword).
  # eval exits 0 even on Lua errors and prints "ok" on success, so the
  # output — not the exit code — is the success signal. The probe reads the
  # monitor JSON's top-level `refreshRate` (0.55 emits no currentMode
  # object).
  hyprlandDaemon = pkgs.writeShellApplication {
    name = "battery-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.hyprland
      # AC/battery probe shared with modules/hardware/ryzen-tdp.nix
      pkgs.is-on-ac
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      ${daemonText
        ''
          hyprctl -j monitors | jq -r '.[] | select(.name=="${panel.output}") | .refreshRate | round'
        ''
        ''
          local out
          out=$(hyprctl eval "hl.monitor({output='${panel.output}', mode='$1', position='${panel.position}', scale='${panel.scale}'})" 2>&1) || true
          if [ "$out" != "ok" ]; then
            echo "battery-refresh: hyprctl eval failed: $out" >&2
            return 1
          fi
        ''
        false
        panel.mode
        batMode
      }
    '';
  };

  # niri session: `niri msg` talks to the compositor over NIRI_SOCKET,
  # which niri-session imports into the systemd user manager where this
  # runs as a service (verified via `systemctl --user show-environment`).
  # The probe reads the output JSON's current_mode — an index into the
  # modes array — whose refresh_rate is in MILLIHERTZ; `/ 1000 | round`
  # yields the integer Hz the shared loop compares. Apply uses niri's mode
  # grammar, which matches strings EXACTLY against the EDID list (three
  # decimals, so plain "@60" would never match): resolution-only "WxH"
  # selects the highest rate (AC), the battery mode spells the full
  # @N.000 form. `niri msg` exits non-zero on failure (no hyprctl-style
  # lying exit codes), so failed probes/applies retry on the next poll.
  niriDaemon = pkgs.writeShellApplication {
    name = "battery-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.niri
      # AC/battery probe shared with modules/hardware/ryzen-tdp.nix
      pkgs.is-on-ac
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      ${daemonText
        ''
          niri msg -j outputs | jq -r '.["${panel.output}"].modes[.["${panel.output}"].current_mode].refresh_rate / 1000 | round'
        ''
        ''
          niri msg output "${panel.output}" mode "$1"
        ''
        false
        wxh
        "${wxh}@${toString cfg.refreshRate}.000"
      }
    '';
  };

  # GNOME session: gnome-monitor-config talks to mutter's DisplayConfig
  # D-Bus API and exits non-zero on failure. Single instance is guaranteed
  # by systemd.
  gnomeDaemon = pkgs.writeShellApplication {
    name = "battery-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnome-monitor-config
      pkgs.gnused
      # AC/battery probe shared with modules/hardware/ryzen-tdp.nix
      pkgs.is-on-ac
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      ${daemonText
        ''
          # `list` marks the active mode with a trailing " CURRENT"; exactly
          # one logical monitor is expected (the ext guard already refuses
          # to act when an external output is connected). jq does the
          # rounding — locale-free, and %g may print a fractional rate.
          local cur hz
          cur=$(gnome-monitor-config list | grep ' CURRENT$') || return 1
          [ "$(printf '%s\n' "$cur" | wc -l)" -eq 1 ] || return 1
          hz=$(printf '%s\n' "$cur" | sed -n 's/^.*@\([0-9.][0-9.]*\) .*/\1/p')
          [ -n "$hz" ] || return 1
          printf '%s\n' "$hz" | jq -r 'round'
        ''
        ''gnome-monitor-config set -L -p -M ${panel.output} -m "$1" -s ${panel.scale} -t normal -x ${posX} -y ${posY}''
        true
        panel.mode
        batMode
      }
    '';
  };
in
{
  options.desktop.battery-refresh = {
    enable = lib.mkEnableOption "switching the internal panel to a lower refresh rate on battery (systemd user service; niri via niri msg, Hyprland via hyprctl eval, GNOME via gnome-monitor-config; panel taken from desktop.hyprland.monitors)";

    refreshRate = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Refresh rate (Hz) to use on battery";
    };

    pollInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Seconds between power/lid state checks";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = withRate != [ ];
        message = "desktop.battery-refresh: desktop.hyprland.monitors needs an entry with an explicit WxH@Hz mode (that entry is the panel definition for every session)";
      }
    ];

    # One service shape for every session, bound to the graphical session.
    # Unlike the old hyprland.start spawn, a user service restarts on a
    # rebuild `switch` (fixes land mid-session, no relogin) and its stderr
    # lands in the journal.
    systemd.user.services.battery-refresh = {
      Unit = {
        Description = "Switch internal panel to ${toString cfg.refreshRate} Hz on battery";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # Backend precedence: niri > Hyprland > GNOME, kept explicit and
        # order-stable — during the trial a Hyprland-backend unit once ran
        # against a live niri session (hyprctl's connection error piped
        # into jq = parse-error spam every poll), exactly the ambiguity an
        # explicit precedence removes.
        ExecStart =
          if config.desktop.niri.enable then
            "${niriDaemon}/bin/battery-refresh"
          else if config.desktop.hyprland.enable then
            "${hyprlandDaemon}/bin/battery-refresh"
          else
            "${gnomeDaemon}/bin/battery-refresh";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
