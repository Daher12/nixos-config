# NixOS VM tests for the litellm gateway module and the SSH source-restricted
# firewall pattern used on hosts/yoga.
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.litellm-gateway
#   nix build .#nixosTests.x86_64-linux.ssh-firewall
{
  testers,
  pkgs,
  lib,
  litellmModule,
}:
{
  litellm-gateway = testers.runNixOSTest {
    name = "litellm-gateway";
    nodes.server = _: {
      imports = [ litellmModule ];

      # Static test config; production uses a sops-rendered path instead.
      environment.etc."litellm-test-config.yaml".text = ''
        model_list:
          - model_name: test-model
            litellm_params:
              model: openai/test
              api_key: dummy
      '';

      features.litellm = {
        enable = true;
        configFile = "/etc/litellm-test-config.yaml";
      };
    };

    testScript = ''
      server.start()
      server.wait_for_unit("litellm.service")
      server.wait_until_succeeds("ss -tln | grep -q '127.0.0.1:4001'")
      # Gateway is actually serving (liveliness endpoint, HTTP 200 required).
      server.succeed("curl -sf http://127.0.0.1:4001/health/liveliness")
      # …and the unit is active.
      server.succeed("systemctl is-active litellm.service")
    '';
  };

  ssh-firewall = testers.runNixOSTest {
    name = "ssh-firewall";
    nodes = {
      server = _: {
        services.openssh = {
          enable = true;
          openFirewall = false;
        };
        # Mirrors the nftables-backend source restriction from
        # hosts/yoga/default.nix (networking.nftables.enable + extraInputRules).
        networking = {
          nftables.enable = true;
          useNetworkd = true;
          firewall = {
            allowPing = true;
            extraInputRules = ''
              ip saddr 192.168.88.0/24 tcp dport 22 ct state new accept comment "ssh from home management LAN"
            '';
          };
        };
        systemd.network = {
          enable = true;
          networks."10-eth1" = {
            matchConfig.Name = "eth1";
            address = [ "192.168.88.1/24" ];
          };
          networks."20-eth2" = {
            matchConfig.Name = "eth2";
            address = [ "10.9.9.1/24" ];
          };
        };
        # eth1 = VLAN 1 (home LAN), eth2 = VLAN 2 (foreign network).
        virtualisation.vlans = [
          1
          2
        ];
      };

      client = _: {
        networking = {
          useNetworkd = true;
        };
        systemd.network = {
          enable = true;
          networks."10-eth1" = {
            matchConfig.Name = "eth1";
            address = [ "192.168.88.50/24" ];
          };
          networks."20-eth2" = {
            matchConfig.Name = "eth2";
            address = [ "10.9.9.50/24" ];
          };
        };
        virtualisation.vlans = [
          1
          2
        ];
      };
    };

    testScript = ''
      start_all()
      server.wait_for_unit("sshd.service")
      client.wait_for_unit("systemd-networkd.service")

      # From the home management LAN: SSH port reachable.
      client.succeed("timeout 10 ${lib.getExe pkgs.netcat} -z 192.168.88.1 22")

      # From a foreign network: firewall drops it.
      client.fail("timeout 5 ${lib.getExe pkgs.netcat} -z 10.9.9.1 22")
    '';
  };
}
