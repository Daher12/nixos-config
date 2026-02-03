{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.virtualization;
  w11 = cfg.windows11;

  waitForKvm = pkgs.writeShellScript "wait-for-kvm" ''
    # Wait up to ~5s for /dev/kvm (covers early-boot / udev timing)
    for i in $(seq 1 50); do
      [ -c /dev/kvm ] && exit 0
      sleep 0.1
    done
    echo "Timed out waiting for /dev/kvm" >&2
    exit 1
  '';

  virsh = "${pkgs.libvirt}/bin/virsh";

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
          ${lib.optionalString w11.enable "<host mac='${w11.mac}' name='${w11.name}' ip='${w11.ip}'/>"}
        </dhcp>
      </ip>
    </network>
  '';
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    windows11 = {
      enable = lib.mkEnableOption "Windows 11 VM (network/DHCP convenience)";

      name = lib.mkOption {
        type = lib.types.str;
        default = "windows11";
        description = "Libvirt domain name";
      };

      mac = lib.mkOption {
        type = lib.types.str;
        default = "52:54:00:00:00:01";
        description = "VM MAC address for DHCP reservation";
      };

      ip = lib.mkOption {
        type = lib.types.str;
        default = "192.168.122.10";
        description = "Static IP assigned via DHCP";
      };
    };

    performance = {
      hugepages = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable 2M hugepages for VM memory";
        };
        count = lib.mkOption {
          type = lib.types.int;
          default = 4096;
          description = "Number of 2M hugepages (4096 = 8GB)";
        };
      };
    };

    includeGuestTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include libguestfs packages";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";

      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];

        # DEFINE ONCE: base config + optional hugepages addon
        verbatimConfig = ''
          user = "qemu"
          group = "kvm"
        ''
        + lib.optionalString cfg.performance.hugepages.enable ''
          hugetlbfs_mount = "/dev/hugepages"
        '';
      };

      extraConfig = ''
        unix_sock_group = "libvirtd"
        unix_sock_ro_perms = "0777"
        unix_sock_rw_perms = "0770"
        auth_unix_ro = "none"
        auth_unix_rw = "none"
        log_filters="3:qemu 1:libvirt"
        log_outputs="2:file:/var/log/libvirt/libvirtd.log"
      '';
    };

    programs.virt-manager.enable = true;

    environment.systemPackages =
      with pkgs;
      [
        virt-manager
        virt-viewer
        swtpm
        OVMFFull
        remmina
        freerdp
        adwaita-icon-theme
      ]
      ++ lib.optionals cfg.includeGuestTools [
        libguestfs
        libguestfs-with-appliance
      ];

    users.users.${mainUser}.extraGroups = lib.mkAfter [
      "libvirtd"
      "kvm"
    ];

    boot.kernelModules = [
      "vhost-net"
      "vhost-vsock"
    ];

    services.udev.extraRules = ''
      KERNEL=="kvm", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';

    # DEFINE ONCE and append conditionally
    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/images 0775 root libvirtd - -"
    ]
    ++ lib.optionals cfg.performance.hugepages.enable [
      "d /dev/hugepages 1755 root kvm - -"
    ];

    systemd.services = lib.mkMerge [
      {
        libvirtd = {
          # Wait for /dev/kvm without relying on dev-kvm.device tracking
          serviceConfig = {
            ExecStartPre = lib.mkAfter [ waitForKvm ];
            TimeoutStartSec = "10s";
          };
        };

        libvirt-guests.serviceConfig = {
          TimeoutStopSec = "30s";
        };
      }

      (lib.mkIf w11.enable {
        libvirt-network-default = {
          description = "Configure libvirt default network";
          after = [ "libvirtd.socket" ];
          requires = [ "libvirtd.socket" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ! ${virsh} net-info default &>/dev/null; then
              ${virsh} net-define ${defaultNetworkXml}
              ${virsh} net-autostart default
            fi
            ${virsh} net-start default 2>/dev/null || true
          '';
        };
      })
    ];

    # Hugepages kernel params (optional)
    boot.kernelParams = lib.mkIf cfg.performance.hugepages.enable [
      "hugepagesz=2M"
      "hugepages=${toString cfg.performance.hugepages.count}"
      "transparent_hugepage=never"
    ];
  };
}
