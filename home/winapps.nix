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
    ip = "192.168.122.10";
    name = "windows11";
  } osConfig;

  secretsFile = "${config.xdg.configHome}/winapps/secrets.conf";
in
{
  options.programs.winapps = {
    enable = lib.mkEnableOption "WinApps integration";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = vmCfg.name;
      description = "Libvirt VM name";
    };

    vmIP = lib.mkOption {
      type = lib.types.str;
      default = vmCfg.ip;
      description = "VM IP address";
    };

    windowsDomain = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "Windows domain/workgroup for RDP";
    };

    # Lean defaults for local VM + Office:
    # - gfx AVC 444: crisp text, good for Office
    # - clipboard: must-have
    # - cert-ignore: avoid friction
    # - auto-reconnect: usability
    rdpFlags = lib.mkOption {
      type = lib.types.str;
      default = "/gfx:avc444 /clipboard /cert-ignore +auto-reconnect";
      description = "FreeRDP flags";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = secretsFile;
      description = "Path to credentials file";
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
      RDP_IP="${cfg.vmIP}"
      RDP_DOMAIN="${cfg.windowsDomain}"
      RDP_FLAGS="${cfg.rdpFlags}"
      FREERDP_COMMAND="${pkgs.freerdp}/bin/xfreerdp"
      VM_NAME="${cfg.vmName}"
      MULTIMON="false"
      DEBUG="false"

      [ -f "${cfg.credentialsFile}" ] && . "${cfg.credentialsFile}"
    '';

    home.activation.winappsSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SECRETS="${cfg.credentialsFile}"
      if [ ! -f "$SECRETS" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$SECRETS")"
        $DRY_RUN_CMD tee "$SECRETS" > /dev/null << 'EOF'
      # WinApps Credentials (not tracked in git)
      RDP_USER="your-windows-username"
      RDP_PASS="your-windows-password"
      EOF
        $DRY_RUN_CMD chmod 600 "$SECRETS"
        verboseEcho "Created WinApps secrets template: $SECRETS"
      fi
    '';
  };
}
