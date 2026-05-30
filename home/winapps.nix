{
  config,
  lib,
  pkgs,
  osConfig ? { },
  winappsPackages,
  ...
}:

let
  cfg = config.programs.winapps;

  vmCfg = lib.attrByPath [ "features" "virtualization" "windows11" ] {
    enable = false;
    name = "windows11";
    ip = null;
  } osConfig;

  secretsFile = "${config.xdg.configHome}/winapps/secrets.conf";

  freerdpCommand = pkgs.writeShellScript "winapps-xfreerdp" ''
    if [ -x "${pkgs.freerdp}/bin/xfreerdp3" ]; then
      exec "${pkgs.freerdp}/bin/xfreerdp3" "$@"
    fi

    exec "${pkgs.freerdp}/bin/xfreerdp" "$@"
  '';
in
{
  options.programs.winapps = {
    enable = lib.mkEnableOption "WinApps integration over libvirt/RDP";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = vmCfg.name;
      description = "Libvirt VM name";
    };

    vmIP = lib.mkOption {
      type = with lib.types; nullOr str;
      default = vmCfg.ip;
      description = ''
        Optional guest IPv4 address.
        Leave null for WinApps libvirt auto-detection.
      '';
    };

    windowsDomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Windows domain; leave empty for local accounts";
    };

    rdpScale = lib.mkOption {
      type = lib.types.enum [
        100
        140
        180
      ];
      default = 100;
      description = "WinApps display scaling factor";
    };

    rdpFlags = lib.mkOption {
      type = lib.types.str;
      default = "/cert:tofu /clipboard +auto-reconnect /gfx:avc444 +home-drive";
      description = "Base FreeRDP flags for WinApps sessions";
    };

    rdpFlagsNonWindows = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra FreeRDP flags for RemoteApp launches";
    };

    rdpFlagsWindows = lib.mkOption {
      type = lib.types.str;
      default = "/dynamic-resolution";
      description = "Extra FreeRDP flags for full desktop sessions";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WinApps debug logging";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = secretsFile;
      description = "Path to WinApps credentials file";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = winappsPackages != null;
        message = "winappsPackages must be provided via extraSpecialArgs";
      }
      {
        assertion =
          !(lib.hasAttrByPath [ "features" "virtualization" "windows11" ] osConfig)
          || (vmCfg.enable or false);
        message = "winapps requires host features.virtualization.windows11.enable = true (when osConfig provides it)";
      }
    ];

    home.packages = [
      winappsPackages.winapps
      winappsPackages.winapps-launcher
      pkgs.freerdp
    ];

    xdg.configFile."winapps/winapps.conf".text = ''
      WAFLAVOR="libvirt"
      VM_NAME="${cfg.vmName}"
      RDP_DOMAIN="${cfg.windowsDomain}"
      RDP_SCALE="${toString cfg.rdpScale}"
      REMOVABLE_MEDIA="/run/media"
      RDP_FLAGS="${cfg.rdpFlags}"
      RDP_FLAGS_NON_WINDOWS="${cfg.rdpFlagsNonWindows}"
      RDP_FLAGS_WINDOWS="${cfg.rdpFlagsWindows}"
      FREERDP_COMMAND="${freerdpCommand}"
      MULTIMON="false"
      DEBUG="${if cfg.debug then "true" else "false"}"
      AUTOPAUSE="off"
      ${lib.optionalString (cfg.vmIP != null) ''RDP_IP="${cfg.vmIP}"''}

      [ -f "${cfg.credentialsFile}" ] && . "${cfg.credentialsFile}"
    '';

    home.activation.winappsSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SECRETS="${cfg.credentialsFile}"

      if [ ! -f "$SECRETS" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$SECRETS")"
        $DRY_RUN_CMD tee "$SECRETS" > /dev/null <<'EOF'
      # WinApps credentials
      RDP_USER="your-windows-username"
      RDP_PASS="your-windows-password"
      EOF
        $DRY_RUN_CMD chmod 600 "$SECRETS"
        verboseEcho "Created WinApps secrets template: $SECRETS"
      fi
    '';
  };
}
