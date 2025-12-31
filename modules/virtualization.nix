{ config, pkgs, ... }:

{
  # ------------------------------------------------------------
  # Libvirt / QEMU (WinApps via libvirt)
  # ------------------------------------------------------------
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
  };

  programs.virt-manager.enable = true;

  # Spice: clipboard/resolution integration + USB redirection
  virtualisation.spiceUSBRedirection.enable = true;
  services.spice-vdagentd.enable = true;
  
  environment.systemPackages = with pkgs; [
    virt-viewer remmina freerdp spice spice-gtk spice-protocol win-spice adwaita-icon-theme
  ];
}
