{ config, lib, pkgs, winappsPackages, ... }:

let
  cfg = config.programs.winapps;
  localConf = "${config.home.homeDirectory}/.config/winapps/winapps.conf.local";
  
  winappsSetup = pkgs.writeShellApplication {
    name = "winapps-setup";
    runtimeInputs = with pkgs; [ libvirt ];
    text = ''
      set -euo pipefail
      
      VM_NAME="${cfg.vmName}"
      EXPECTED_IP="${cfg.vmIP}"
      
      echo "WinApps VM Setup Check"
      echo "======================"
      
      if ! virsh list --all | grep -q "$VM_NAME"; then
        echo "❌ VM '$VM_NAME' not found"
        echo ""
        echo "Create Windows 11 VM with these settings:"
        echo "  - Name: $VM_NAME"
        echo "  - MAC: ${cfg.vmMAC} (for static IP)"
        echo "  - Network: default (NAT)"
        echo "  - Enable TPM 2.0"
        echo "  - Use UEFI with Secure Boot"
        echo "  - Install VirtIO drivers (run: get-virtio-win)"
        exit 1
      fi
      
      if ! virsh list --state-running | grep -q "$VM_NAME"; then
        echo "⚠ VM '$VM_NAME' is not running"
        echo "Start with: virsh start $VM_NAME"
        exit 1
      fi
      
      VM_IP=$(virsh domifaddr "$VM_NAME" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -n1 || echo "")
      
      if [ -z "$VM_IP" ]; then
        echo "⚠ VM IP not detected yet (may still be booting)"
      elif [ "$VM_IP" != "$EXPECTED_IP" ]; then
        echo "⚠ VM IP is $VM_IP (expected $EXPECTED_IP)"
        echo "Update MAC address or DHCP reservation"
      else
        echo "✓ VM IP: $VM_IP"
      fi
      
      if [ ! -f "${localConf}" ]; then
        echo "⚠ WinApps config not found: ${localConf}"
        echo "Run: winapps-configure"
        exit 1
      fi
      
      if ! grep -q "RDP_IP=" "${localConf}"; then
        echo "⚠ RDP_IP not configured"
        exit 1
      fi
      
      echo ""
      echo "✓ Setup appears correct"
      echo ""
      echo "Next steps:"
      echo "  1. Ensure Windows RDP is enabled"
      echo "  2. Configure user credentials in ${localConf}"
      echo "  3. Test with: winapps"
    '';
  };

  winappsConfig = pkgs.writeShellApplication {
    name = "winapps-configure";
    text = ''
      set -euo pipefail
      
      CONF="${localConf}"
      
      if [ -f "$CONF" ]; then
        echo "Config already exists: $CONF"
        echo "Edit manually or remove to regenerate"
        exit 0
      fi
      
      mkdir -p "$(dirname "$CONF")"
      
      cat > "$CONF" <<'EOF'
# WinApps Configuration
# Keep this file at 0600 (chmod 0600)

RDP_IP="${cfg.vmIP}"
RDP_USER="your_windows_username"
RDP_PASS="your_windows_password"

RDP_SCALE=${toString cfg.rdpScale}
MULTIMON="${if cfg.multiMonitor then "true" else "false"}"

RDP_FLAGS="${cfg.rdpFlags}"

DEBUG="${if cfg.debug then "true" else "false"}"
EOF
      
      chmod 0600 "$CONF"
      
      echo "✓ Created config template: $CONF"
      echo ""
      echo "Edit the file and set:"
      echo "  - RDP_USER: Windows username"
      echo "  - RDP_PASS: Windows password"
      echo ""
      echo "Then run: winapps-setup"
    '';
  };
in
{
  options.programs.winapps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WinApps integration";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "windows11";
      description = "Name of Windows VM";
    };

    vmIP = lib.mkOption {
      type = lib.types.str;
      default = "192.168.122.10";
      description = "Static IP of Windows VM";
    };

    vmMAC = lib.mkOption {
      type = lib.types.str;
      default = "52:54:00:00:00:01";
      description = "MAC address for static DHCP reservation";
    };

    rdpScale = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "RDP scaling percentage";
    };

    multiMonitor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable multi-monitor support";
    };

    rdpFlags = lib.mkOption {
      type = lib.types.str;
      default = "/gfx:avc444 /rfx /gfx-h264:avc444 +glyph-cache +bitmap-cache /sound:sys:alsa /cert-ignore /compression /dynamic-resolution /network:auto";
      description = "Additional RDP flags";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable debug mode";
    };

    desktopEntries = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create desktop entries for common apps";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.winappsConfigDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.config/winapps"
    '';

    home.activation.winappsTemplate = lib.hm.dag.entryAfter [ "winappsConfigDir" ] ''
      if [ ! -e "${localConf}" ]; then
        $DRY_RUN_CMD ${winappsConfig}/bin/winapps-configure
      fi
    '';

    xdg.configFile."winapps/winapps.conf".source =
      config.lib.file.mkOutOfStoreSymlink localConf;

    home.packages = [
      winappsPackages.winapps
      winappsPackages.winapps-launcher
      winappsSetup
      winappsConfig
    ];

    xdg.desktopEntries = lib.mkIf cfg.desktopEntries {
      itunes = {
        name = "iTunes";
        exec = "winapps iTunes";
        icon = "multimedia-audio-player";
        categories = [ "AudioVideo" "Audio" ];
        comment = "iTunes via Windows VM";
      };
      
      word = {
        name = "Microsoft Word";
        exec = "winapps WINWORD.EXE";
        icon = "libreoffice-writer";
        categories = [ "Office" "WordProcessor" ];
        comment = "Microsoft Word via Windows VM";
      };
      
      excel = {
        name = "Microsoft Excel";
        exec = "winapps EXCEL.EXE";
        icon = "libreoffice-calc";
        categories = [ "Office" "Spreadsheet" ];
        comment = "Microsoft Excel via Windows VM";
      };
      
      powerpoint = {
        name = "Microsoft PowerPoint";
        exec = "winapps POWERPNT.EXE";
        icon = "libreoffice-impress";
        categories = [ "Office" "Presentation" ];
        comment = "Microsoft PowerPoint via Windows VM";
      };
    };
  };
}
