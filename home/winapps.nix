{ config, lib, pkgs, winappsPackages, ... }:

let
  cfg = config.programs.winapps;
  secretsFile = "${config.xdg.configHome}/winapps/secrets.conf";
in
{
  options.programs.winapps = {
    enable = lib.mkEnableOption "WinApps integration";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "windows11";
      description = "Libvirt VM Name";
    };

    vmIP = lib.mkOption {
      type = lib.types.str;
      default = "192.168.122.10";
      description = "Static IP of the VM";
    };

    rdpFlags = lib.mkOption {
      type = lib.types.str;
      default = "/gfx:avc444 /sound:sys:alsa /cert-ignore /dynamic-resolution";
      description = "RDP performance flags";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = secretsFile;
      description = "Path to local file containing RDP_USER and RDP_PASS";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = winappsPackages != null;
        message = "winappsPackages must be provided via extraSpecialArgs when programs.winapps.enable is true";
      }
    ];

    home.packages = [
      winappsPackages.winapps
      winappsPackages.winapps-launcher
      pkgs.freerdp
      pkgs.netcat
    ];

    # Wrapper script that sources credentials before launching
    xdg.configFile."winapps/winapps.conf".source =
      let
        configScript = pkgs.writeShellScript "winapps-config" ''
          # Functional Settings
          export RDP_IP="${cfg.vmIP}"
          export RDP_DOMAIN="${cfg.vmName}"
          export RDP_FLAGS="${cfg.rdpFlags}"
          export FREERDP_COMMAND="xfreerdp"
          export MULTIMON="false"
          export DEBUG="true"

          # Load Secrets
          if [ -f "${cfg.credentialsFile}" ]; then
            . "${cfg.credentialsFile}"
          else
            echo "WARNING: Secrets file not found at ${cfg.credentialsFile}" >&2
          fi
        '';
      in configScript;

    home.activation.winappsSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SECRETS="${cfg.credentialsFile}"

      if [ ! -f "$SECRETS" ]; then
        run mkdir -p "$(dirname "$SECRETS")"

        run cat > "$SECRETS" << 'EOF'
# WinApps Credentials (Local Only - gitignored)
# These will be sourced by the launcher wrapper.

RDP_USER="CHANGE_ME"
RDP_PASS="CHANGE_ME"
EOF

        run chmod 600 "$SECRETS"
        echo "Created WinApps secrets template at $SECRETS"
      fi
    '';
  };
}
