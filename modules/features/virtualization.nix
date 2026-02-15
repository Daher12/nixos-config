# modules/features/virtualization.nix (lean, no hugepages; btrfs NoCOW; Win11 optional packages;
# ensures libvirt 'default' network is active)
{ config
, lib
, pkgs
, mainUser
, ...
}:

let
  cfg = config.features.virtualization;
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization (lean)";

    spiceUSBRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE USB redirection";
    };

    windows11.enable = lib.mkEnableOption "Windows 11 convenience (host-side packages only)";
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      libvirtd = {
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
          unix_sock_rw_perms = "0770"
        '';
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
        OVMFFull
        remmina
        freerdp
        adwaita-icon-theme
      ]
      ++ lib.optionals cfg.spiceUSBRedirection [
        usbredir
        spice-gtk
      ]
      ++ lib.optionals cfg.windows11.enable [
        win-spice
      ];

    users.users = {
      ${mainUser}.extraGroups = lib.mkAfter [
        "libvirtd"
        "kvm"
      ];

      # Fix 2: effective QEMU user needs kvm for /dev/kvm 0660
      qemu-libvirtd.extraGroups = lib.mkAfter [ "kvm" ];
    };

    services.udev.extraRules = ''
      KERNEL=="kvm", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';

    # Strategy B: no virt-manager prompts, only for active session
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

    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/images 0775 root libvirtd - -"
    ]
    ++ lib.optionals (config.features.filesystem.type == "btrfs") [
      # btrfs NoCOW for VM images directory
      "h /var/lib/libvirt/images - - - - +C"
    ];

    # Keep libvirt's default NAT network active for VMs that reference network='default'
    systemd.services.libvirt-network-default = {
      description = "Ensure libvirt default network is active";
      after = [ "libvirtd.socket" ];
      requires = [ "libvirtd.socket" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-start default 2>/dev/null || true
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-autostart default 2>/dev/null || true
      '';
    };
  };
}
