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
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    windows11 = {
      enable = lib.mkEnableOption "Windows 11 VM with Office/iTunes optimizations";
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

      vcpus = lib.mkOption {
        type = lib.types.int;
        default = 4;
      };

      memory = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "Memory in MiB";
      };

      diskSize = lib.mkOption {
        type = lib.types.int;
        default = 80;
        description = "Disk size in GiB";
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
      ioThreads = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Recommend I/O threads in VM XML";
      };
    };

    includeGuestTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include virtio-win and libguestfs";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        virtualisation.libvirtd = {
          enable = true;
          onBoot = "ignore";
          onShutdown = "shutdown";

          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = false;
            swtpm.enable = true;
            vhostUserPackages = [ pkgs.virtiofsd ];
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

        users.users.${mainUser}.extraGroups = lib.mkAfter [
          "libvirtd"
          "kvm"
        ];

        # Feature-level modules only. CPU KVM modules are loaded by hardware modules.
        boot.kernelModules = [
          "vhost-net"
          "vhost-vsock"
        ];

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

        programs.virt-manager.enable = true;

        # Hardening: Restrict KVM access to root and kvm group (0660).
        services.udev.extraRules = ''
          KERNEL=="kvm", GROUP="kvm", MODE="0660"
          SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
        '';

        # Finite shutdown timeout to avoid hanging on stop.
        systemd.services.libvirt-guests.serviceConfig = {
          TimeoutStopSec = "30s";
        };
      }

      {
        virtualisation.libvirtd.qemu.verbatimConfig = ''
          user = "qemu"
          group = "kvm"
        '';
      }

      (lib.mkIf cfg.performance.hugepages.enable {
        boot.kernelParams = [
          "hugepagesz=2M"
          "hugepages=${toString cfg.performance.hugepages.count}"
          "transparent_hugepage=never"
        ];

        systemd.tmpfiles.rules = [
          "d /dev/hugepages 1755 root kvm - -"
        ];

        # Append to existing qemu verbatimConfig.
        virtualisation.libvirtd.qemu.verbatimConfig = lib.mkAfter ''
          hugetlbfs_mount = "/dev/hugepages"
        '';
      })

      (lib.mkIf w11.enable (
        let
          # Only create this derivation when Windows11 support is enabled.
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
          assertions = [
            {
              assertion = cfg.includeGuestTools && config.virtualisation.libvirtd.qemu.swtpm.enable;
              message = "features.virtualization.windows11 requires includeGuestTools and swtpm.enable";
            }
          ];

          systemd.tmpfiles.rules = [
            "d /var/lib/libvirt/images 0775 root libvirtd - -"
          ]
          ++ lib.optional (config.features.filesystem.type == "btrfs") "h /var/lib/libvirt/images - - - - +C";

          systemd.services.libvirt-network-default = {
            description = "Configure libvirt default network";
            after = [ "libvirtd.socket" ];
            requires = [ "libvirtd.socket" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script =
              let
                virsh = "${pkgs.libvirt}/bin/virsh";
              in
              ''
                if ! ${virsh} net-info default &>/dev/null; then
                  ${virsh} net-define ${defaultNetworkXml}
                  ${virsh} net-autostart default
                fi
                ${virsh} net-start default 2>/dev/null || true
              '';
          };
        }
      ))
    ]
  );
}
