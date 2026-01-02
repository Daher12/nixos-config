{ config, lib, pkgs, ... }:

let
  cfg = config.features.virtualization;
  mainUser = config.core.users.mainUser;
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    spice = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Spice integration for clipboard/USB";
    };

    performance = {
      hugepages = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable hugepages for VM memory";
      };
      hugepageSize = lib.mkOption {
        type = lib.types.str;
        default = "2M";
        description = "Hugepage size (2M or 1G)";
      };
      ioScheduler = lib.mkOption {
        type = lib.types.enum [ "none" "mq-deadline" "kyber" "bfq" ];
        default = "none";
        description = "I/O scheduler for VM disk operations";
      };
    };

    networking = {
      bridge = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Create bridge interface for VMs";
      };
      bridgeName = lib.mkOption {
        type = lib.types.str;
        default = "virbr0";
        description = "Bridge interface name";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Core Virtualization
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

      # User Permissions
      users.users.${mainUser}.extraGroups = [ "libvirtd" "kvm" ];

      # Udev Rules
      services.udev.extraRules = ''
        KERNEL=="kvm", GROUP="kvm", MODE="0666"
        SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      '';

      # Kernel Modules & Params
      boot.kernelModules = [ "kvm-intel" "kvm-amd" "vhost-net" "vhost-vsock" ];
      boot.extraModprobeConfig = ''
        options kvm_intel nested=1 enable_apicv=1 ept=1
        options kvm_amd nested=1 avic=1 npt=1
        options vhost-net experimental_zcopytx=1
      '';

      # Packages
      environment.systemPackages = with pkgs; [
        virt-manager
        virt-viewer
        spice
        spice-gtk
        spice-protocol
        virtio-win
        win-spice
        swtpm
        OVMFFull
        remmina
        freerdp
        libguestfs
        libguestfs-with-appliance
        adwaita-icon-theme
      ];

      # Spice Services
      virtualisation.spiceUSBRedirection.enable = cfg.spice;
      services.spice-vdagentd.enable = cfg.spice;
      programs.virt-manager.enable = true;

      # Networking
      networking.bridges = lib.mkIf cfg.networking.bridge {
        ${cfg.networking.bridgeName}.interfaces = [];
      };
      networking.interfaces = lib.mkIf cfg.networking.bridge {
        ${cfg.networking.bridgeName}.useDHCP = false;
      };

      # Network Start Script
      systemd.services.configure-libvirt-network = {
        description = "Configure libvirt default network";
        after = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          if ! ${pkgs.libvirt}/bin/virsh net-info default > /dev/null 2>&1; then
            ${pkgs.libvirt}/bin/virsh net-define /dev/stdin <<EOF
            <network>
              <name>default</name>
              <forward mode='nat'><nat><port start='1024' end='65535'/></nat></forward>
              <bridge name='virbr0' stp='on' delay='0'/>
              <ip address='192.168.122.1' netmask='255.255.255.0'>
                <dhcp>
                  <range start='192.168.122.100' end='192.168.122.254'/>
                  <host mac='52:54:00:00:00:01' name='windows11' ip='192.168.122.10'/>
                </dhcp>
              </ip>
            </network>
EOF
            ${pkgs.libvirt}/bin/virsh net-autostart default
          fi
          ${pkgs.libvirt}/bin/virsh net-start default || true
        '';
      };
    }

    # Hugepages
    (lib.mkIf cfg.performance.hugepages {
      boot.kernelParams = [
        "hugepagesz=${cfg.performance.hugepageSize}"
        "hugepages=2048"
        "transparent_hugepage=never"
      ];
      systemd.tmpfiles.rules = [
        "d /dev/hugepages 1755 root kvm - -"
        "m /dev/hugepages - - kvm - -"
      ];
    })

    # I/O Scheduler
    (lib.mkIf (cfg.performance.ioScheduler != "none") {
      services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="${cfg.performance.ioScheduler}"
      '';
    })
  ]);
}
