{ config, lib, pkgs, mainUser, ... }:

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

  config = lib.mkIf cfg.enable (lib.mkMerge [
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

      users.users.${mainUser}.extraGroups = lib.mkAfter [ "libvirtd" "kvm" ];

      boot.kernelModules = [ "kvm-intel" "kvm-amd" "vhost-net" "vhost-vsock" ];
      boot.extraModprobeConfig = ''
        options kvm_intel enable_apicv=1 ept=1
        options kvm_amd avic=1 npt=1
      '';

      environment.systemPackages = with pkgs; [
        virt-manager
        virt-viewer
        swtpm
        OVMFFull
        remmina
        freerdp
        adwaita-icon-theme
      ] ++ lib.optionals cfg.includeGuestTools [
        libguestfs
        libguestfs-with-appliance
      ];

      programs.virt-manager.enable = true;

      services.udev.extraRules = ''
        KERNEL=="kvm", GROUP="kvm", MODE="0666"
        SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      '';
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

      virtualisation.libvirtd.qemu.verbatimConfig = lib.mkAfter ''
        hugetlbfs_mount = "/dev/hugepages"
      '';
    })

    (lib.mkIf w11.enable {
      assertions = [{
        assertion = cfg.includeGuestTools;
        message = "features.virtualization.includeGuestTools must be true when windows11.enable is true";
      }];

      systemd.tmpfiles.rules = [
        "d /var/lib/libvirt/images 0775 root libvirtd - -"
      ] ++ lib.optional (config.features.filesystem.type == "btrfs")
        "h /var/lib/libvirt/images - - - - +C";

      systemd.services.libvirt-network-default = {
        description = "Configure libvirt default network";
        after = [ "libvirtd.socket" ];
        requires = [ "libvirtd.socket" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = let
          virsh = "${pkgs.libvirt}/bin/virsh";
        in ''
          if ! ${virsh} net-info default &>/dev/null; then
            ${virsh} net-define /dev/stdin <<'EOF'
<network>
  <name>default</name>
  <forward mode='nat'>
    <nat><port start='1024' end='65535'/></nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.100' end='192.168.122.254'/>
      <host mac='${w11.mac}' name='${w11.name}' ip='${w11.ip}'/>
    </dhcp>
  </ip>
</network>
EOF
            ${virsh} net-autostart default
          fi
          ${virsh} net-start default 2>/dev/null || true
        '';
      };
    })
  ]);
}
