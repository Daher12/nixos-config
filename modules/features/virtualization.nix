{ config, pkgs, lib, ... }:

{
  # 1. Enable Libvirt
  virtualisation.libvirtd = {
    enable = true;
    
    qemu = {
      package = pkgs.qemu_kvm; # or pkgs.qemu for alien arch emulation
      runAsRoot = false;
      swtpm.enable = true;     # Needed for Windows 11 TPM 2.0
      
      # 2. VirtioFS (Modern Replacement)
      vhostUserPackages = [ pkgs.virtiofsd ]; 
    };
  };

  # 3. Modern USB Redirection
  virtualisation.spiceUSBRedirection.enable = true;

  # 4. Firmware & Tools
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice spice-gtk
    win-spice
    
    # Secure Boot Firmware (provides descriptors for QEMU)
    OVMFFull 
    
    # Drivers (Managed Package)
    # ISO Location: ${pkgs.virtio-win}/share/virtio-win/virtio-win.iso
    virtio-win 
  ];

  # 5. Declarative Networking (Standard "Vanilla" Approach)
  # For fully declarative XML, consider the 'NixVirt' flake, 
  # but this service method remains the standard for basic setups.
  systemd.services.libvirt-default-network = {
    description = "Ensure default libvirt network is active";
    wantedBy = [ "multi-user.target" ];
    after = [ "libvirtd.service" ];
    path = [ pkgs.libvirt ];
    script = ''
      if ! virsh net-uuid default >/dev/null 2>&1; then
        virsh net-define ${pkgs.writeText "default.xml" ''
          <network>
            <name>default</name>
            <forward mode='nat'/>
            <bridge name='virbr0' stp='on' delay='0'/>
            <ip address='192.168.122.1' netmask='255.255.255.0'>
              <dhcp>
                <range start='192.168.122.100' end='192.168.122.254'/>
              </dhcp>
            </ip>
          </network>
        ''}
        virsh net-autostart default
      fi
      virsh net-start default || true
    '';
  };
}
