{ config, lib, pkgs, ... }:

let
  cfg = config.features.virtualization;
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    spice = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Spice integration for clipboard/USB";
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
      };
    };

    programs.virt-manager.enable = true;

    virtualisation.spiceUSBRedirection.enable = cfg.spice;
    services.spice-vdagentd.enable = cfg.spice;
    
    environment.systemPackages = with pkgs; [
      virt-viewer 
      remmina 
      freerdp 
      spice 
      spice-gtk 
      spice-protocol 
      win-spice 
      adwaita-icon-theme
    ];
  };
}
