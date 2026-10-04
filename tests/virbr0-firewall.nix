# NixOS VM test for the scoped virbr0 firewall holes in
# modules/features/virtualization.nix: the libvirt default network needs
# DHCP (udp/67) and DNS (53) to reach the host dnsmasq, while everything
# else arriving on the NAT bridge must stay dropped — no blanket
# trustedInterfaces trust, or a guest could reach arbitrary host services.
#
# The firewall rules come from the real module (imported below), so the
# test fails if someone widens the holes or reinstates blanket trust.
# libvirtd itself is kept out of the closure (we test the INPUT policy,
# not libvirt): networkd builds the same topology (bridge virbr0 with a
# port, host address 192.168.122.1) and services.dnsmasq plays the
# default network's DHCP/DNS role.
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.virbr0-firewall
{
  testers,
  pkgs,
  lib,
  virtualizationModule,
  filesystemModule,
}:

let
  dig = lib.getExe' pkgs.bind.dnsutils "dig";
in
{
  virbr0-firewall = testers.runNixOSTest {
    name = "virbr0-firewall";

    nodes = {
      server =
        { lib, ... }:
        {
          _module.args.mainUser = "root";
          imports = [
            virtualizationModule
            filesystemModule
          ];

          # Firewall shape under test, exactly as deployed on yoga.
          networking.nftables.enable = true;

          features.filesystem.type = "ext4";
          features.virtualization = {
            enable = true;
            virtioWinIso = false; # keep the ~700 MB ISO out of the closure
            spiceUSBRedirection = false;
          };

          # The unit under test is the input policy — no libvirt/qemu in
          # the closure, and its network-ensure unit stays idle. The
          # module still sets users.users.qemu-libvirtd.extraGroups,
          # which creates a partial user entry — complete it the way
          # nixpkgs' libvirtd module otherwise would.
          virtualisation.libvirtd.enable = lib.mkForce false;
          systemd.services.libvirt-default-network.wantedBy = lib.mkForce [ ];
          users.users.qemu-libvirtd = {
            isSystemUser = true;
            group = "qemu-libvirtd";
          };
          users.groups.qemu-libvirtd = { };

          networking = {
            useNetworkd = true;
            useDHCP = false;
          };

          systemd.network = {
            enable = true;
            netdevs."10-virbr0".netdevConfig = {
              Name = "virbr0";
              Kind = "bridge";
            };
            networks."10-virbr0" = {
              matchConfig.Name = "virbr0";
              address = [ "192.168.122.1/24" ];
            };
            networks."20-eth1" = {
              matchConfig.Name = "eth1";
              bridge = [ "virbr0" ];
            };
          };

          services.dnsmasq = {
            enable = true;
            settings = {
              interface = "virbr0";
              # virbr0 may not exist yet when dnsmasq starts — bind as it appears.
              bind-dynamic = true;
              # No upstream resolv.conf in the VM: serve the local record below.
              no-resolv = true;
              address = "/nas.libvirt.internal/192.168.122.1";
              dhcp-range = "192.168.122.100,192.168.122.200,12h";
            };
          };

          virtualisation.vlans = [ 3 ];
        };

      # Stands in for the Windows guest: one port on the same bridge.
      client = _: {
        networking = {
          useNetworkd = true;
          useDHCP = false;
        };
        systemd.network = {
          enable = true;
          networks."10-eth1" = {
            matchConfig.Name = "eth1";
            DHCP = "yes";
          };
        };
        virtualisation.vlans = [ 3 ];
      };
    };

    testScript = ''
      start_all()

      server.wait_for_unit("systemd-networkd.service")
      server.wait_until_succeeds("ip link show virbr0")
      server.wait_for_unit("dnsmasq.service")
      client.wait_for_unit("systemd-networkd.service")

      # DHCP: the client must obtain a 192.168.122.x lease from the host —
      # proves udp/67 input on virbr0 passes the scoped rule. If the rule
      # were missing, networkd would retry forever and this times out.
      client.wait_until_succeeds(
          "ip -4 addr show dev eth1 | grep -q '192.168.122.'", timeout=60
      )

      # DNS over UDP and TCP (dnsmasq answers from its local record) —
      # proves both /53 rules pass.
      client.succeed(
          "${dig} +short +time=2 +tries=1 @192.168.122.1 nas.libvirt.internal | grep -qx 192.168.122.1"
      )
      client.succeed(
          "${dig} +tcp +short +time=2 +tries=1 @192.168.122.1 nas.libvirt.internal | grep -qx 192.168.122.1"
      )

      # Everything else from the bridge must stay dropped. A canary HTTP
      # server on the host is reachable locally but NOT from the guest.
      server.succeed(
          "systemd-run --unit=virbr0-canary ${lib.getExe pkgs.python3} -m http.server 8080 --bind 0.0.0.0"
      )
      # wait_for_unit returns while python is still importing — poll the port.
      server.wait_for_open_port(8080)
      server.succeed("${lib.getExe pkgs.curl} -sf -o /dev/null http://127.0.0.1:8080/")
      client.fail("timeout 5 ${lib.getExe pkgs.netcat} -z 192.168.122.1 8080")

      # Ruleset shape: the three scoped virbr0 rules are actually loaded.
      server.succeed("nft list ruleset | grep -F 'iifname \"virbr0\" udp dport 67 accept'")
      server.succeed("nft list ruleset | grep -F 'iifname \"virbr0\" udp dport 53 accept'")
      server.succeed("nft list ruleset | grep -F 'iifname \"virbr0\" tcp dport 53 accept'")
    '';
  };
}
