{ config, lib, ... }:

let
  cfg = config.core.openssh;
in
{
  options.core.openssh = {
    enable = lib.mkEnableOption "OpenSSH server with the fleet-hardened defaults";
  };

  config = lib.mkIf cfg.enable {
    # Common hardening previously duplicated per-host (yoga, latitude,
    # nix-media). Per-host extras (ports, openFirewall) stay in the host
    # modules and merge over these mkDefaults.
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
        UseDns = lib.mkDefault false;
      };
    };
  };
}
