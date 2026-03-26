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

  filesystemType = lib.attrByPath [ "features" "filesystem" "type" ] null config;

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
          ${lib.optionalString (
            w11.ip != null && w11.mac != null
          ) "<host mac='${w11.mac}' name='${w11.name}' ip='${w11.ip}'/>"}
        </dhcp>
      </ip>
    </network>
  '';
in
{
  options.features.virtualization = {
    enable = lib.mkEnableOption "libvirt/QEMU virtualization";

    spiceUSBRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE USB redirection on the host";
    };

    windows11 = {
      enable = lib.mkEnableOption "Windows 11 host-side conveniences";

      name = lib.mkOption {
        type = lib.types.str;
        default = "windows11";
        description = "Libvirt VM name for the Windows 11 guest";
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
          Set together with windows11.ip if you want a DHCP reservation.
        '';
      };
    };
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
      ++ lib.optionals w11.enable [
        win-spice
      ];

    environment.variables.LIBVIRT_DEFAULT_URI = "qemu:///system";

    users.users.${mainUser}.extraGroups = lib.mkAfter [
      "libvirtd"
      "kvm"
    ];

    users.users.qemu-libvirtd.extraGroups = lib.mkAfter [ "kvm" ];

    services.udev.extraRules = ''
      KERNEL=="kvm", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';

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
    ++ lib.optionals (filesystemType == "btrfs") [
      "h /var/lib/libvirt/images - - - - +C"
    ];

    systemd.services.libvirt-default-network = {
      description = "Ensure libvirt default network exists and is active";
      after = [ "libvirtd.socket" ];
      requires = [ "libvirtd.socket" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script =
        let
          virsh = "${pkgs.libvirt}/bin/virsh -c qemu:///system";
        in
        ''
          if ! ${virsh} net-info default >/dev/null 2>&1; then
            ${virsh} net-define ${defaultNetworkXml}
          fi

          ${virsh} net-autostart default >/dev/null 2>&1 || true
          ${virsh} net-start default >/dev/null 2>&1 || true
        '';
    };
  };
}
