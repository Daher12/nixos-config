{ config, lib, pkgs, winappsPackages, ... }:

let
  cfg = config.programs.winapps;
  # The static config managed by Nix
  configFile = "winapps/winapps.conf";
  # The mutable secrets file (Not managed by Nix content, just path)
  secretsFile = "${config.xdg.configHome}/winapps/secrets.conf";
in
{
  options.programs.winapps = {
    enable = lib.mkEnableOption "WinApps integration";

    # Safe / Functional Configuration
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

    # Secret Management Path
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = secretsFile;
      description = "Path to local file containing RDP_USER and RDP_PASS";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Install Packages
    home.packages = [
      winappsPackages.winapps
      winappsPackages.winapps-launcher
      pkgs.freerdp 
      pkgs.netcat
    ];

    # 2. Generate Main Configuration (Public Safe)
    xdg.configFile.${configFile}.text = ''
      # MANAGED BY NIX - DO NOT EDIT FUNCTIONAL SETTINGS
      # Functional Settings
      RDP_IP="${cfg.vmIP}"
      RDP_DOMAIN="${cfg.vmName}"
      RDP_FLAGS="${cfg.rdpFlags}"
      
      # Fixed Settings
      FREERDP_COMMAND="xfreerdp"
      MULTIMON="false"
      DEBUG="true"

      # Load Secrets (User/Pass)
      # This file is not managed by Nix content, just path.
      if [ -f "${cfg.credentialsFile}" ]; then
          . "${cfg.credentialsFile}"
      else
          echo "WARNING: Secrets file not found at ${cfg.credentialsFile}" >&2
      fi
    '';

    # 3. Activation: Bootstrap Secrets Template (Idempotent)
    home.activation.winappsSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SECRETS="${cfg.credentialsFile}"
      
      if [ ! -f "$SECRETS" ]; then
        echo "Creating WinApps secrets template at $SECRETS"
        mkdir -p "$(dirname "$SECRETS")"
        
        cat > "$SECRETS" <<EOF
      # WinApps Credentials (Local Only - gitignored)
      # Fill these in. They will be sourced by the main config.
      
      RDP_USER="CHANGE_ME"
      RDP_PASS="CHANGE_ME"
      EOF
        
        # Secure permissions (User read/write only)
        chmod 600 "$SECRETS"
      fi
    '';
  };
}
