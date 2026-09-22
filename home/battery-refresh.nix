{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.battery-refresh;

  # The panel definition is shared by both sessions: hosts set
  # desktop.hyprland.monitors even on GNOME-only attrs, so the first entry
  # with an explicit WxH@Hz mode is the internal panel in either session.
  monitors = config.desktop.hyprland.monitors;
  withRate = lib.filter (m: builtins.match ".+@[0-9.]+" m.mode != null) monitors;

  panel = builtins.head withRate;
  modeParts = builtins.match "(.+)@([0-9.]+)" panel.mode;
  batMode = "${lib.head modeParts}@${toString cfg.refreshRate}";

  posParts = builtins.match "(-?[0-9]+)x(-?[0-9]+)" panel.position;
  posX = if posParts != null then lib.head posParts else "0";
  posY = if posParts != null then lib.elemAt posParts 1 else "0";

  # Shared loop logic: re-derive (power, lid[, ext]) every pollInterval
  # seconds and apply the mode whenever the observed state changed and the
  # guards pass. `last` only advances on a successful apply or a guard
  # block, so a failed apply retries on the next poll instead of being
  # swallowed until the next state change (compositor socket races at
  # session start, transient D-Bus errors).
  #
  # Trigger conditions (deliberate, all of them):
  #   - AC plug/unplug  -> switch 120 Hz <-> battery refresh rate
  #   - lid reopen      -> re-apply (the lid switch restores the configured
  #                        120 Hz mode; without this the panel would stay at
  #                        120 Hz on battery until the next AC transition)
  #   - lid closed      -> never touch the panel (the lid switch disabled
  #                        it; applying to a disabled panel is at best a
  #                        no-op and at worst re-enables it — reload-on-open
  #                        restores the configured mode anyway)
  #   - external output connected (GNOME only) -> never touch the panel
  #                        (`set -L` replaces the whole monitor configuration)
  #
  # applyFn must return non-zero on failure (the loop relies on it).
  daemonText = applyFn: extGuard: ''
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

    apply() {
      ${applyFn}
    }

    can_apply() {
      [ "$lid" = open ] || return 1
      ${lib.optionalString extGuard ''
        [ "$ext" = "none" ] || return 1
      ''}
      return 0
    }

    last=""
    while true; do
      if is_on_ac; then pwr=ac; else pwr=bat; fi
      if lid_open; then lid=open; else lid=closed; fi
      ${lib.optionalString extGuard ''
        if ext_connected; then ext=ext; else ext=none; fi
      ''}
      state="$pwr,$lid${lib.optionalString extGuard ",$ext"}"
      if [ "$state" != "$last" ]; then
        if can_apply; then
          if [ "$pwr" = ac ]; then
            if apply "${panel.mode}"; then last="$state"; fi
          else
            if apply "${batMode}"; then last="$state"; fi
          fi
        else
          last="$state"
        fi
      fi
      sleep ${toString cfg.pollInterval}
    done
  '';

  # Hyprland session: hyprctl talks to the compositor (uwsm imports
  # HYPRLAND_INSTANCE_SIGNATURE/XDG_RUNTIME_DIR into the user manager, where
  # this runs as a service).
  #
  # Hyprland 0.55 moved monitors into the Lua config parser, where the old
  # `hyprctl keyword monitor ...` is refused ("keyword can't work with
  # non-legacy parsers") while still exiting 0 — a silent no-op that looked
  # healthy for weeks. The runtime path is `hyprctl eval` on hl.monitor.
  # eval ALSO exits 0 on Lua errors and prints "ok" on success, so the
  # output — not the exit code — is the success signal.
  hyprlandDaemon = pkgs.writeShellApplication {
    name = "battery-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.hyprland
    ];
    text = ''
      set -euo pipefail

      ${daemonText ''
        local out
        out=$(hyprctl eval "hl.monitor({output='${panel.output}', mode='$1', position='${panel.position}', scale='${panel.scale}'})" 2>&1) || true
        if [ "$out" != "ok" ]; then
          echo "battery-refresh: hyprctl eval failed: $out" >&2
          return 1
        fi
      '' false}
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
    ];
    text = ''
      set -euo pipefail

      ${daemonText ''gnome-monitor-config set -L -p -M ${panel.output} -m "$1" -s ${panel.scale} -t normal -x ${posX} -y ${posY}'' true}
    '';
  };
in
{
  options.desktop.battery-refresh = {
    enable = lib.mkEnableOption "switching the internal panel to a lower refresh rate on battery (systemd user service in both sessions: Hyprland via hyprctl eval, GNOME via gnome-monitor-config; panel taken from desktop.hyprland.monitors)";

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
        message = "desktop.battery-refresh: desktop.hyprland.monitors needs an entry with an explicit WxH@Hz mode (that entry is the panel definition for both sessions)";
      }
    ];

    # One service shape for both sessions, bound to the graphical session.
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
        ExecStart =
          if config.desktop.hyprland.enable then
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
