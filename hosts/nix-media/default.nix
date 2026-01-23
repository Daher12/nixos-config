{
  pkgs,
  lib,
  mainUser,
  ...
}:

{
  imports = [
    # Hardware & Architecture
    ./hardware-configuration.nix
    ../../modules/hardware/intel-gpu.nix

    # Service Modules
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix # Encapsulates auto-upgrade & reboot logic

    # Global Features
    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
  ];

  # ---------------------------------------------------------------------------
  # Core Configuration
  # ---------------------------------------------------------------------------
  core.users.defaultShell = "zsh";
  core.sysctl.optimizeForServer = true;

  system.stateVersion = "24.05";

  # ---------------------------------------------------------------------------
  # Boot & Kernel Tuning
  # ---------------------------------------------------------------------------
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];

    # Host-specific sysctl overrides (additive to core.sysctl.optimizeForServer)
    kernel.sysctl = {
      "vm.dirty_writeback_centisecs" = 200;
    };
  };

  # ---------------------------------------------------------------------------
  # Hardware & Graphics
  # ---------------------------------------------------------------------------
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    xfsprogs
    wget
    mosh
    ethtool
    nvme-cli
    smartmontools
    trash-cli
    unrar
    unzip
    ox
    btop
    fastfetchMinimal
  ];

  # ---------------------------------------------------------------------------
  # Networking (systemd-networkd)
  # ---------------------------------------------------------------------------
  networking = {
    # 1. Disable the desktop-oriented NetworkManager
    # (Overrides core mkDefault from modules/core/networking.nix)
    networkmanager.enable = false;

    # 2. Enable systemd-networkd (Server standard)
    useNetworkd = true;
    
    # 3. Explicitly overwrite hardware-configuration.nix legacy settings
    # This ensures we don't run two DHCP clients or have ambiguous config.
    interfaces.enp1s0.useDHCP = lib.mkForce false;
    
    # 4. Firewall (WoL is now handled by networkd below)
    firewall.allowedTCPPorts = [ 2049 ];
  };
  
  # 5. Define the Link Configuration (Physical Layer)
  systemd.network.links."10-enp1s0" = {
    matchConfig.Name = "enp1s0";
    linkConfig = {
      # Native networkd WoL handling (replaces legacy networking.interfaces.*.wakeOnLan)
      WakeOnLan = "magic";
    };
  };

  # 6. Define the Network Configuration (Logical Layer)
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      # Explicit IPv4 only to avoid timeouts/delays from partial IPv6
      DHCP = "ipv4";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no"; 
    };
    # Critical: If using AdGuard/PiHole, uncomment below to stop DHCP DNS override
    # dhcpV4Config.UseDNS = false;
  };
  
  # 7. Ensure maintenance services wait for VALID network connectivity
  systemd.network.wait-online = {
    enable = true;
    timeout = 30;
    # Scope to enp1s0 AND require it to be 'routable' (DHCP done + routes present).
    # This guarantees network-online.target truly means "internet ready".
    extraArgs = [ "--interface=enp1s0:routable" ];
  };

  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------
  users.users.${mainUser}.extraGroups = [ "docker" ];

  # ---------------------------------------------------------------------------
  # Services
  # ---------------------------------------------------------------------------
  services = {
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=500M
      SystemMaxFileSize=50M
      MaxRetentionSec=2592000
      RateLimitInterval=30s
      RateLimitBurst=1000
    '';
    logrotate.enable = true;

    openssh = {
      enable = true;
      ports = [ 26 ];
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        UseDns = false;
      };
    };

    rpcbind.enable = lib.mkForce false;
    nfs = {
      server = {
        enable = true;
        exports = ''
          /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash)
        '';
      };
      settings.nfsd = {
        vers3 = "n";
        udp = "n";
      };
    };

    fstrim = {
      enable = true;
      interval = "weekly";
    };
    thermald.enable = true;

    # Headless Optimizations (stripping unused desktop/audio stacks)
    pipewire.enable = false;
    pulseaudio.enable = false;
    libinput.enable = false;
    udisks2.enable = false;
    flatpak.enable = false;
    fwupd.enable = false;
  };

  features.sops.enable = true;
  security.rtkit.enable = false;
}
