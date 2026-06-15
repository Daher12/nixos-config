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

  vmName = w11.name;

  windows11-icon = pkgs.stdenv.mkDerivation {
    pname = "windows11-icon";
    version = "1.0";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cat > $out/share/icons/hicolor/256x256/apps/windows11.svg <<'SVG'
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
        <rect width="256" height="256" rx="32" fill="#0078D4"/>
        <g fill="#fff">
          <rect x="28" y="28" width="100" height="100" rx="8"/>
          <rect x="148" y="28" width="100" height="100" rx="8"/>
          <rect x="28" y="148" width="100" height="100" rx="8"/>
          <rect x="148" y="148" width="100" height="100" rx="8"/>
        </g>
      </svg>
      SVG
    '';
  };

  windows11-launcher = pkgs.writeShellScriptBin "windows11" ''
    virsh="${pkgs.libvirt}/bin/virsh -c qemu:///system"
    viewer="${pkgs.virt-viewer}/bin/virt-viewer"

    if ! $virsh dominfo "${vmName}" >/dev/null 2>&1; then
      echo "VM '${vmName}' not found. Define it in virt-manager first." >&2
      exit 1
    fi

    state=$($virsh domstate "${vmName}" 2>/dev/null | tr -d '[:space:]')

    if [ "$state" != "running" ]; then
      echo "Starting ${vmName}..."
      $virsh start "${vmName}"
      echo "Waiting for guest to boot..."
      for _ in $(seq 1 30); do
        sleep 2
        state=$($virsh domstate "${vmName}" 2>/dev/null | tr -d '[:space:]')
        if [ "$state" = "running" ]; then
          sleep 5
          break
        fi
      done
    fi

    exec $viewer --full-screen --connect "qemu:///system" "${vmName}"
  '';

  windows11-desktop = pkgs.makeDesktopItem {
    name = "windows11";
    desktopName = "Windows 11";
    comment = "Full Windows 11 desktop session via SPICE";
    exec = "${windows11-launcher}/bin/windows11";
    icon = "windows11";
    terminal = false;
    categories = [
      "System"
      "Emulator"
    ];
  };

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
    assertions = [
      {
        assertion =
          config.features.filesystem.type != "btrfs"
          || lib.elem "discard=async" (config.fileSystems."/".options or [ ])
          || config.services.fstrim.enable;
        message = "features.virtualization: btrfs +C flag requires either discard=async or periodic fstrim for proper TRIM";
      }
    ];

    virtualisation = {
      libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";
        shutdownTimeout = 10;

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
        remmina
        freerdp
        adwaita-icon-theme
        windows11-launcher
        windows11-desktop
        windows11-icon
      ]
      ++ lib.optionals cfg.spiceUSBRedirection [
        usbredir
        spice-gtk
      ];

    environment.variables.LIBVIRT_DEFAULT_URI = "qemu:///system";

    users.users.${mainUser}.extraGroups = lib.mkAfter [
      "libvirtd"
      "kvm"
    ];

    users.users.qemu-libvirtd.extraGroups = lib.mkAfter [
      "kvm"
      "input" # Required for evdev passthrough (not in core/users.nix for this user)
    ];

    services.udev.extraRules = ''
      KERNEL=="kvm", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';

    # Allow QEMU (non-root) to lock memory for Hugepages
    security.pam.loginLimits = [
      {
        domain = "qemu-libvirtd";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];

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
          # Only redefine if XML changed (e.g. DHCP reservation update)
          current_xml=$(${virsh} net-dumpxml default 2>/dev/null || true)
          new_xml=$(cat ${defaultNetworkXml})
          if [ "$current_xml" != "$new_xml" ]; then
            if ${virsh} net-info default >/dev/null 2>&1; then
              ${virsh} net-destroy default 2>/dev/null || true
              ${virsh} net-undefine default 2>/dev/null || true
            fi
            ${virsh} net-define ${defaultNetworkXml}
          fi
          ${virsh} net-autostart default >/dev/null 2>&1 || true
          if ! ${virsh} net-info default 2>/dev/null | grep -q "Active:.*yes"; then
            ${virsh} net-start default >/dev/null 2>&1 || true
          fi
        '';
    };
  };
}
