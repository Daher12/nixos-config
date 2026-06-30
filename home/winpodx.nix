{
  config,
  lib,
  pkgs,
  winpodxPackage,
  ...
}:

let
  cfg = config.programs.winpodx;

  # Build a space-delimited whitelist for shell case matching
  whitelistStr = lib.concatStringsSep " " cfg.apps;

  syncAppsSh = ''
    WHITELIST="${whitelistStr}"

    # Fix read-only icon permissions — install_winpodx_icon() uses
    # shutil.copy2 which preserves the Nix store's 0444 permissions,
    # causing "[Errno 13] Keine Berechtigung" when the GUI writes to it.
    ICON="$HOME/.local/share/icons/hicolor/scalable/apps/winpodx.svg"
    [ -f "$ICON" ] && chmod 644 "$ICON" || true

    ${winpodxPackage}/bin/winpodx app list 2>/dev/null | tail -n +4 | awk '{print $1}' | while read name; do
      case " $WHITELIST " in
        *" $name "*)
          ${winpodxPackage}/bin/winpodx app show "$name" 2>/dev/null || true
          ;;
        *)
          ${winpodxPackage}/bin/winpodx app hide "$name" 2>/dev/null || true
          ;;
      esac
    done
  '';

  winpodx-apps-script = pkgs.writeShellScript "winpodx-apps" ''
    set -e
    ${syncAppsSh}

    # Discover new apps from the Windows guest (timeout: don't block activation)
    ${pkgs.coreutils}/bin/timeout 120 ${winpodxPackage}/bin/winpodx app refresh 2>/dev/null || true

    ${syncAppsSh}
  '';

  # Sync-only script (no refresh) for the delayed timer — catches desktop
  # entries recreated by the GUI (gui/workers.py:118) or provisioner
  # (provisioner.py:673), both of which call install_desktop_entry for
  # ALL apps without checking the hidden flag (unlike the daemon at
  # core/daemon.py:354 which skips hidden apps correctly).
  winpodx-apps-sync-script = pkgs.writeShellScript "winpodx-apps-sync" ''
    ${syncAppsSh}
  '';
in
{
  options.programs.winpodx = {
    enable = lib.mkEnableOption "WinPodX — seamless Windows app integration via FreeRDP RemoteApp + dockur/windows";

    apps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "file-explorer"
        "microsoft-edge"
        "tiptoi-manager"
        "itunes"
      ];
      description = "WinPodX apps visible in the Linux desktop menu";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = winpodxPackage != null;
        message = "winpodxPackage must be provided via extraSpecialArgs";
      }
    ];

    home.packages = [
      winpodxPackage
    ];

    # NOTE: winpodx.toml is NOT managed by home-manager — it's an
    # imperative config written by `winpodx setup` and persisted via
    # impermanence (~/.config/winpodx). Using home.file here would
    # create a read-only Nix store symlink that blocks winpodx setup
    # from writing the real config.

    systemd.user.services.winpodx-apps = {
      Unit = {
        Description = "Configure WinPodX visible apps";
        After = [ "graphical-session.target" ];
        Requires = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${winpodx-apps-script}";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # Delayed re-sync: catches desktop entries the GUI/provisioner recreate
    # during startup after our initial sync ran. One-shot, not periodic.
    systemd.user.services.winpodx-apps-sync = {
      Unit = {
        Description = "Re-sync WinPodX visible apps (delayed startup)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${winpodx-apps-sync-script}";
      };
    };

    systemd.user.timers.winpodx-apps-sync = {
      Unit = {
        Description = "Delayed re-sync of WinPodX visible apps after GUI startup";
      };
      Timer = {
        OnBootSec = "3min";
        Unit = "winpodx-apps-sync.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
