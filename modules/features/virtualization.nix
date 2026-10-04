{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.virtualization;
  filesystemType = config.features.filesystem.type;
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    spiceUSBRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE USB redirection on the host";
    };

    virtioWinIso = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Expose the upstream virtio-win driver ISO (~700 MB in the system
        closure) as /var/lib/libvirt/images/virtio-win.iso for Windows
        guests. Attach it as a CDROM during Windows installation so setup
        can load the virtio storage/network drivers.
      '';
    };

    guests = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          submodule (
            { name, ... }:
            {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Libvirt domain name for this guest";
                };

                desktopName = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Name shown in the desktop launcher";
                };

                description = lib.mkOption {
                  type = lib.types.str;
                  default = "Full Windows 11 desktop session via SPICE";
                  description = "Comment shown in the desktop launcher";
                };

                iconColor = lib.mkOption {
                  type = lib.types.str;
                  default = "#0078D4";
                  description = "Background color of the generated launcher icon";
                };

                badge = lib.mkOption {
                  type = with lib.types; nullOr str;
                  default = null;
                  description = ''
                    Optional short label drawn on the launcher icon (e.g. "WORK")
                    to distinguish guests at a glance.
                  '';
                };

                ip = lib.mkOption {
                  type = with lib.types; nullOr str;
                  default = null;
                  description = ''
                    Optional fixed guest IPv4 address.
                    Leave null to let libvirt DHCP assign an address dynamically.
                  '';
                };

                mac = lib.mkOption {
                  type = with lib.types; nullOr str;
                  default = null;
                  description = ''
                    Optional guest MAC address.
                    Set together with the guest ip if you want a DHCP reservation.
                    Must match the NIC MAC configured in virt-manager.
                  '';
                };
              };
            }
          )
        );
      default = { };
      description = "Windows guests to generate launchers and DHCP reservations for";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      guests = lib.mapAttrs (guestName: guest: rec {
        icon = pkgs.stdenv.mkDerivation {
          pname = "${guestName}-icon";
          version = "1.0";
          dontUnpack = true;
          installPhase = ''
              mkdir -p $out/share/icons/hicolor/256x256/apps
              cat > $out/share/icons/hicolor/256x256/apps/${guestName}.svg <<'SVG'
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
                <rect width="256" height="256" rx="32" fill="${guest.iconColor}"/>
                <g fill="#fff">
                  <rect x="28" y="28" width="100" height="100" rx="8"/>
                  <rect x="148" y="28" width="100" height="100" rx="8"/>
                  <rect x="28" y="148" width="100" height="100" rx="8"/>
                  <rect x="148" y="148" width="100" height="100" rx="8"/>
                </g>
                ${lib.optionalString (guest.badge != null) ''
                  <rect x="140" y="196" width="108" height="42" rx="12" fill="#1f2937"/>
                  <text x="194" y="224" font-family="sans-serif" font-size="26" font-weight="bold" fill="#fff" text-anchor="middle">${guest.badge}</text>
                ''}
              </svg>
            SVG
          '';
        };

        launcher = pkgs.writeShellScriptBin guestName ''
          virsh="${pkgs.libvirt}/bin/virsh -c qemu:///system"
          viewer="${pkgs.virt-viewer}/bin/virt-viewer"

          # spice-gtk finds spice-client-glib-usb-acl-helper through $PATH,
          # and only the /run/wrappers/bin copy carries cap_fowner (needed
          # to ACL the usb node for the user). Pin it via the upstream env
          # override so USB redirection survives launchers that hand us a
          # minimal PATH (lucid dock, 2026-10-01).
          export SPICE_USB_ACL_BINARY="/run/wrappers/bin/spice-client-glib-usb-acl-helper"

          if ! $virsh dominfo "${guest.name}" >/dev/null 2>&1; then
            echo "VM '${guest.name}' not found. Define it in virt-manager first." >&2
            exit 1
          fi

          state=$($virsh domstate "${guest.name}" 2>/dev/null | tr -d '[:space:]')

          if [ "$state" != "running" ]; then
            echo "Starting ${guest.name}..."
            $virsh start "${guest.name}"
            echo "Waiting for guest to boot..."
            for _ in $(seq 1 30); do
              sleep 2
              state=$($virsh domstate "${guest.name}" 2>/dev/null | tr -d '[:space:]')
              if [ "$state" = "running" ]; then
                sleep 5
                break
              fi
            done
          fi

          exec $viewer --full-screen --connect "qemu:///system" "${guest.name}"
        '';

        desktop = pkgs.makeDesktopItem {
          name = guestName;
          inherit (guest) desktopName;
          comment = guest.description;
          exec = "${launcher}/bin/${guestName}";
          icon = guestName;
          terminal = false;
          categories = [
            "System"
            "Emulator"
          ];
        };
      }) cfg.guests;

      guestPackages = lib.concatLists (
        lib.mapAttrsToList (_: guest: [
          guest.launcher
          guest.desktop
          guest.icon
        ]) guests
      );

      # pkgs.virtio-win installs the *extracted* ISO tree; .src is the
      # pristine upstream ISO, which is what virt-manager can attach as a CDROM.
      virtioWinIso = pkgs.virtio-win.src;

      dhcpReservations = lib.concatStrings (
        lib.mapAttrsToList (
          _: guest:
          lib.optionalString (
            guest.ip != null && guest.mac != null
          ) "<host mac='${guest.mac}' name='${guest.name}' ip='${guest.ip}'/>"
        ) cfg.guests
      );

      defaultNetworkXml = pkgs.writeText "libvirt-default-net.xml" ''
        <network>
          <name>default</name>
          <forward mode='nat'>
            <nat><port start='1024' end='65535'/></nat>
          </forward>
          <bridge name='virbr0' stp='on' delay='0'/>
          <ip address='192.168.122.1' netmask='255.255.255.0'>
            <dhcp>
              <range start='192.168.122.100' end='192.168.122.254'/>
              ${dhcpReservations}
            </dhcp>
          </ip>
        </network>
      '';
    in
    {
      assertions = [
        {
          assertion =
            config.features.filesystem.type != "btrfs"
            || lib.elem "discard=async" config.fileSystems."/".options
            || config.services.fstrim.enable;
          message = "features.virtualization: btrfs +C flag requires either discard=async or periodic fstrim for proper TRIM";
        }
      ];

      virtualisation = {
        libvirtd = {
          enable = true;
          # nixpkgs auto-derives the firewall backend: "nftables" when
          # networking.nftables.enable is true. That silent flip
          # (2026-09-13) broke this host's default-network NAT — guests
          # DHCP'd fine but had no internet ("connected, no internet",
          # observed 2026-09). Pin the long-proven iptables backend; its
          # iptables-nft rules live in separate tables/chains
          # (LIBVIRT_*) and coexist with inet nixos-fw, which only ever
          # replaces its own table.
          firewallBackend = "iptables";
          onBoot = "ignore";
          onShutdown = "shutdown";
          shutdownTimeout = 10;

          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = false;
            swtpm.enable = true;
            vhostUserPackages = [ pkgs.virtiofsd ];
          };
        };

        spiceUSBRedirection.enable = cfg.spiceUSBRedirection;
      };

      programs.virt-manager.enable = true;

      environment.systemPackages =
        with pkgs;
        [
          virt-manager
          virt-viewer
          swtpm
          remmina
          freerdp
          adwaita-icon-theme
        ]
        ++ guestPackages
        ++ lib.optionals cfg.spiceUSBRedirection [
          usbredir
          spice-gtk
        ];

      environment.variables.LIBVIRT_DEFAULT_URI = "qemu:///system";

      # The NixOS nftables firewall's input chain has policy drop and
      # only trusts lo/tailscale0 — DHCP/DNS guest→host traffic arriving
      # on virbr0 was dropped even though libvirt's own iptables chains
      # accept it: an ACCEPT in one nft table cannot override another
      # table's drop (guests "identifying → unidentified network",
      # observed 2026-09-30). Open the two ports the default network's
      # dnsmasq actually needs instead of blanket-trusting the bridge —
      # guests keep reaching ONLY DHCP and DNS on the host, nothing else.
      # extraInputRules is nftables-only (silently ignored on the
      # iptables backend, where libvirt's rules coexist with the NixOS
      # firewall in the same table anyway). Behavior is pinned by
      # tests/virbr0-firewall.nix.
      networking.firewall.extraInputRules = ''
        iifname "virbr0" udp dport 67 accept comment "libvirt default network: DHCP"
        iifname "virbr0" udp dport 53 accept comment "libvirt default network: DNS"
        iifname "virbr0" tcp dport 53 accept comment "libvirt default network: DNS (TCP fallback)"
      '';

      users.users.${mainUser}.extraGroups = lib.mkAfter [
        "libvirtd"
        "kvm"
      ];

      users.users.qemu-libvirtd.extraGroups = lib.mkAfter [
        "kvm"
        "input" # Required for evdev passthrough (not in core/users.nix for this user)
      ];

      services.udev.extraRules = ''
        KERNEL=="kvm", GROUP="kvm", MODE="0660"
        SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      '';

      # Allow QEMU (non-root) to lock memory for Hugepages
      security.pam.loginLimits = [
        {
          domain = "qemu-libvirtd";
          type = "-";
          item = "memlock";
          value = "unlimited";
        }
      ];

      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.unix.manage" ||
               action.id == "org.libvirt.unix.monitor") &&
              subject.user == "${mainUser}" &&
              subject.active) {
            return polkit.Result.YES;
          }
        });
      '';

      systemd = {
        tmpfiles.rules = [
          "d /var/lib/libvirt/images 0775 root libvirtd - -"
        ]
        ++ lib.optionals (filesystemType == "btrfs") [
          "h /var/lib/libvirt/images - - - - +C"
        ]
        ++ lib.optionals cfg.virtioWinIso [
          "L+ /var/lib/libvirt/images/virtio-win.iso - - - - ${virtioWinIso}"
        ];

        services.libvirt-default-network = {
          description = "Ensure libvirt default network exists and is active";
          after = [ "libvirtd.socket" ];
          requires = [ "libvirtd.socket" ];
          wantedBy = [ "multi-user.target" ];

          # RemainAfterExit deliberately off: a timer cannot re-run an active
          # oneshot (start on an active unit is a no-op), and the script is
          # read-only when the network is in sync.
          serviceConfig.Type = "oneshot";

          script =
            let
              virsh = "${pkgs.libvirt}/bin/virsh -c qemu:///system";
            in
            ''
              # Redefine only on real drift. `virsh net-dumpxml` emits
              # libvirt's canonical XML — it injects <uuid> and the bridge
              # <mac> and reformats whitespace — so a raw string compare
              # against the store file never matches. That made this unit
              # destroy+recreate the network at EVERY boot (and on every
              # nixpkgs-bump unit restart), unplugging the NIC of any
              # running guest: VMs randomly lost networking (observed
              # 2026-09). Normalize both sides before comparing.
              norm() { sed -e 's|<uuid>[^<]*</uuid>||' -e "s|<mac address='[^']*'/>||" | tr -d ' \n\t'; }
              current_xml=$(${virsh} net-dumpxml default 2>/dev/null | norm || true)
              new_xml=$(norm < ${defaultNetworkXml})
              if [ "$current_xml" != "$new_xml" ] && [ -n "$new_xml" ]; then
                if [ -z "$current_xml" ]; then
                  ${virsh} net-define ${defaultNetworkXml}
                elif [ -n "$(${virsh} list --state-running --name 2>/dev/null || true)" ]; then
                  # Destroying the network would unplug running guests'
                  # NICs without re-attaching them. Defer the redefine to
                  # the next run instead (next boot / unit restart).
                  echo "libvirt-default-network: XML drift detected, but domains are running — deferring redefine" >&2
                else
                  ${virsh} net-destroy default 2>/dev/null || true
                  ${virsh} net-undefine default 2>/dev/null || true
                  ${virsh} net-define ${defaultNetworkXml}
                fi
              fi
              ${virsh} net-autostart default >/dev/null 2>&1 || true
              if ! ${virsh} net-info default 2>/dev/null | grep -q "Active:.*yes"; then
                # Errors NOT swallowed: a failed net-start must show up in
                # the journal and mark the unit failed, instead of
                # silently leaving the network down until the next reboot.
                ${virsh} net-start default
              fi
            '';
        };

        timers.libvirt-default-network = {
          description = "Re-run libvirt default-network drift check (applies deferred redefines once no guests are running)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "15min";
            OnUnitInactiveSec = "6h";
          };
        };
      };
    }
  );
}
