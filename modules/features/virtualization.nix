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
    # Base Configuration
    {
      assertions = [
        {
          assertion = builtins.elem mainUser config.users.users.${mainUser}.extraGroups;
          message = "Main user must exist in system configuration";
        }
      ];
      # Core virtualization stack
      virtualisation.libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";
        
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;
          
          # TPM 2.0 for Windows 11
          swtpm.enable = true;
          # UEFI firmware with Secure Boot
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMFFull.fd ];
          };
          
          # VirtIO-FS for shared folders
          vhostUserPackages = [ pkgs.virtiofsd ];
        };

        # Allow user access without password
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

      # Ensure user has proper group membership
      users.users.${mainUser}.extraGroups = [ "libvirtd" "kvm" ];
      
      # KVM permissions
      services.udev.extraRules = ''
        KERNEL=="kvm", GROUP="kvm", MODE="0666"
        SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      '';
      
      # Networking
      networking.bridges = lib.mkIf cfg.networking.bridge {
        ${cfg.networking.bridgeName}.interfaces = [];
      };
      networking.interfaces = lib.mkIf cfg.networking.bridge {
        ${cfg.networking.bridgeName} = {
          useDHCP = false;
        };
      };

      # Performance tuning
      boot.kernelModules = [ 
        "kvm-intel" 
        "kvm-amd" 
        "vhost-net" 
        "vhost-vsock"
      ];
      boot.extraModprobeConfig = ''
        options kvm_intel nested=1 enable_apicv=1 ept=1
        options kvm_amd nested=1 avic=1 npt=1
        options vhost-net experimental_zcopytx=1
      '';
      # Hugepages configuration
      boot.kernelParams = lib.optionals cfg.performance.hugepages [
        "hugepagesz=${cfg.performance.hugepageSize}"
        "hugepages=2048"
        "transparent_hugepage=never"
      ];
      systemd.tmpfiles.rules = lib.optionals cfg.performance.hugepages [
        "d /dev/hugepages 1755 root kvm - -"
        "m /dev/hugepages - - kvm - -"
      ];

      # Spice integration
      virtualisation.spiceUSBRedirection.enable = cfg.spice;
      services.spice-vdagentd.enable = cfg.spice;

      programs.virt-manager.enable = true;
      # Essential packages
      environment.systemPackages = with pkgs;
      [
        virt-manager
        virt-viewer
        spice
        spice-gtk
        spice-protocol
        win-virtio
        win-spice
        swtpm
        
        # RDP clients for winapps
        remmina
        freerdp3
        
        # Utilities
        libguestfs
       
        libguestfs-with-appliance
        
        # Theme support
        adwaita-icon-theme
        
        # Windows guest tools ISO
        (writeShellScriptBin "get-virtio-win" ''
          ISO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
          DEST="$HOME/Downloads/virtio-win.iso"
          
          if [ ! -f "$DEST" ]; then
            echo "Downloading VirtIO drivers for Windows..."
    
            ${curl}/bin/curl -L "$ISO_URL" -o "$DEST"
            echo "Downloaded to $DEST"
          else
            echo "VirtIO drivers already exist at $DEST"
          fi
        '')
      ];
      # Libvirt default network with static DHCP for winapps
      systemd.services.libvirtd-config = {
        description = "Configure libvirt default network for winapps";
        after = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.libvirt}/bin/virsh net-define /dev/stdin <<EOF
          <network>
            <name>default</name>
            <forward mode='nat'>
              <nat>
                <port start='1024' end='65535'/>
              </nat>
            </forward>
          
            <bridge name='virbr0' stp='on' delay='0'/>
            <ip address='192.168.122.1' netmask='255.255.255.0'>
              <dhcp>
                <range start='192.168.122.100' end='192.168.122.254'/>
                <host mac='52:54:00:00:00:01' name='windows11' ip='192.168.122.10'/>
              </dhcp>
            </ip>
          </network>
          
          EOF
          
          ${pkgs.libvirt}/bin/virsh net-autostart default || true
          ${pkgs.libvirt}/bin/virsh net-start default || true
        '';
      };
    }

    # I/O scheduler optimization (Merged Rule)
    (lib.mkIf (cfg.performance.ioScheduler != "none") {
      services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="${cfg.performance.ioScheduler}"
      '';
    })
  ]);
}
