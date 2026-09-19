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
  # guards pass. `last` is updated on every change even when an apply was
  # skipped, so the panel converges when the lid reopens / dock detaches.
  #
  # Trigger conditions (deliberate, all of them):
  #   - AC plug/unplug  -> switch 120 Hz <-> battery refresh rate
  #   - lid reopen      -> re-apply (the lid switch restores the configured
  #                        120 Hz mode; without this the panel would stay at
  #                        120 Hz on battery until the next AC transition)
  #   - lid closed      -> never touch the panel (it is disabled by the lid
  #                        switch; a mode change would re-enable it)
  #   - external output connected (GNOME only) -> never touch the panel
  #                        (`set -L` replaces the whole monitor configuration)
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
            apply "${panel.mode}"
          else
            apply "${batMode}"
          fi
        fi
        last="$state"
      fi
      sleep ${toString cfg.pollInterval}
    done
  '';

  # Hyprland session: spawned via the hyprland.start hook (same pattern as
  # hyprpolkitagent in home/hyprland.nix); uwsm stops the session scope (and
  # with it this daemon) on logout, the flock guards stray double-starts.
  hyprlandDaemon = pkgs.writeShellApplication {
    name = "battery-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.hyprland
    ];
    text = ''
      set -euo pipefail

      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/battery-refresh.lock"
      flock -n 9 || exit 0

      ${daemonText ''hyprctl keyword monitor "${panel.output},$1,${panel.position},${panel.scale}"'' false}
    '';
  };

  # GNOME session: systemd user service (below); gnome-monitor-config talks
  # to mutter's DisplayConfig D-Bus API. Single instance is guaranteed by
  # systemd, no lock needed.
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
    enable = lib.mkEnableOption "switching the internal panel to a lower refresh rate on battery (Hyprland: hyprctl daemon; GNOME: gnome-monitor-config user service; panel taken from desktop.hyprland.monitors)";

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

    # Hyprland attr (.#yoga)
    desktop.hyprland.extraConfig = lib.mkIf config.desktop.hyprland.enable ''
      -- Battery refresh-rate switch on the internal panel (home/battery-refresh.nix)
      hl.on("hyprland.start", function()
          hl.exec_cmd("${hyprlandDaemon}/bin/battery-refresh")
      end)
    '';

    # GNOME attr (.#yoga-gnome): desktop.hyprland.enable is false there
    systemd.user.services.battery-refresh = lib.mkIf (!config.desktop.hyprland.enable) {
      Unit = {
        Description = "Switch internal panel to ${toString cfg.refreshRate} Hz on battery";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${gnomeDaemon}/bin/battery-refresh";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
