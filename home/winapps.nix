{ config, pkgs, lib, winapps, ... }:

let
  # No secrets management: you maintain this file manually and keep it 0600.
  # It is NOT stored in the Nix store.
  localConf = "${config.home.homeDirectory}/.config/winapps/winapps.conf.local";
in
{
  home.activation.winappsConfigDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/.config/winapps"
  '';

  # Create a template once (no password); you fill in RDP_USER/RDP_PASS/RDP_IP.
  home.activation.winappsTemplate = lib.hm.dag.entryAfter [ "winappsConfigDir" ] ''
    if [ ! -e "${localConf}" ]; then
      cat > "${localConf}" <<'EOF'
# Keep this file at 0600.
# Required:
#   RDP_USER="..."
#   RDP_PASS="..."
#   RDP_IP="..."
# Optional:
#   RDP_SCALE=100
#   MULTIMON="true"
#   DEBUG="false"
#   RDP_FLAGS="/gfx:avc444 /sound:sys:alsa /cert-ignore"
EOF
      chmod 0600 "${localConf}"
    fi
  '';

  # WinApps reads ~/.config/winapps/winapps.conf
  xdg.configFile."winapps/winapps.conf".source =
    config.lib.file.mkOutOfStoreSymlink localConf;

  home.packages = [
    winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps
    winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps-launcher
  ];
}

