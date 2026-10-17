{ config, lib, ... }:

let
  cfg = config.core.openssh;
in
{
  options.core.openssh = {
    enable = lib.mkEnableOption "OpenSSH server with the fleet-hardened defaults";

    mgmtLanCidr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.88.0/24";
      description = ''
        IPv4 CIDR of the home management LAN. When set, emits an nftables
        input rule accepting SSH (services.openssh.ports) from this subnet
        only, instead of opening the port on every interface. No effect
        unless networking.nftables.enable is true — like all
        extraInputRules, the rule is silently ignored under the iptables
        backend.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Common hardening previously duplicated per-host (yoga, latitude,
    # nix-media). Per-host extras (ports, openFirewall) stay in the host
    # modules and merge over these mkDefaults.
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        # Key-only auth: upstream defaults KbdInteractiveAuthentication to
        # true, so PAM keyboard-interactive kept offering password prompts
        # even with PasswordAuthentication=no. Fleet policy (2026-10-16):
        # SSH via key or Tailscale, never passwords — load-bearing on
        # nix-media, whose port 26 is deliberately reachable LAN-wide.
        KbdInteractiveAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
        UseDns = lib.mkDefault false;
      };
    };

    networking.firewall.extraInputRules =
      lib.mkIf (cfg.mgmtLanCidr != null && config.networking.nftables.enable)
        (
          lib.concatMapStrings (port: ''
            ip saddr ${cfg.mgmtLanCidr} tcp dport ${toString port} ct state new accept comment "ssh from home management LAN"
          '') config.services.openssh.ports
        );
  };
}
