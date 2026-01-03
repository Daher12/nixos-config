# home/winapps.nix
{ config, lib, pkgs, osConfig ? {}, winappsPackages, ... }:

let
  cfg = config.programs.winapps;

  # Safely access NixOS VM config with fallback defaults
  vmCfg = ((osConfig.features or {}).virtualization or {}).windows11 or {};
  defaultIP = vmCfg.ip or "192.168.122.10";
  defaultName = vmCfg.name or "windows11";

  secretsFile = "${config.xdg.configHome}/winapps/secrets.conf";
in
{
  options.programs.winapps = {
    enable = lib.mkEnableOption "WinApps integration";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = defaultName;
      description = "Libvirt VM name";
    };

    vmIP = lib.mkOption {
      type = lib.types.str;
      default = defaultIP;
      description = "VM IP address";
    };

    windowsDomain = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "Windows domain/workgroup for RDP";
    };

    rdpFlags = lib.mkOption {
      type = lib.types.str;
      default = "/gfx:avc444 /sound:sys:alsa /microphone:sys:alsa /clipboard /cert-ignore /dynamic-resolution +auto-reconnect";
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
    ];

    home.packages = [
      winappsPackages.winapps
      winappsPackages.winapps-launcher
      pkgs.freerdp
      pkgs.netcat
    ];

    xdg.configFile."winapps/winapps.conf".text = ''
      RDP_IP="${cfg.vmIP}"
      RDP_DOMAIN="${cfg.windowsDomain}"
      RDP_FLAGS="${cfg.rdpFlags}"
      FREERDP_COMMAND="xfreerdp"
      MULTIMON="false"
      DEBUG="false"

      # Source credentials if available
      [ -f "${cfg.credentialsFile}" ] && . "${cfg.credentialsFile}"
    '';

    home.activation.winappsSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SECRETS="${cfg.credentialsFile}"
      if [ ! -f "$SECRETS" ]; then
        run mkdir -p "$(dirname "$SECRETS")"
        run cat > "$SECRETS" << 'EOF'
# WinApps Credentials (not tracked in git)
RDP_USER="your-windows-username"
RDP_PASS="your-windows-password"
EOF
        run chmod 600 "$SECRETS"
        verboseEcho "Created WinApps secrets template: $SECRETS"
      fi
    '';
  };
}
