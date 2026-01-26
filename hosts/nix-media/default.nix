{
  pkgs,
  lib,
  mainUser,
  ...
}:

let
  lanIf = "enp1s0";
  sshPort = 26;
  nfsPort = 2049;
  tailscaleCidr = "100.64.0.0/10";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/intel-gpu.nix

    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix # Auto-upgrade & reboot strategies

    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
  ];

  core.users.defaultShell = "zsh";
  core.sysctl.optimizeForServer = true;

  system.stateVersion = "24.05";

  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];
    
    # Aggressive writeback for throughput (additive to core.sysctl)
    kernel.sysctl."vm.dirty_writeback_centisecs" = 200;
  };

  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    xfsprogs
    nvme-cli
    smartmontools
    ethtool
    mosh
    wget
    aria2
    trash-cli
    unrar
    unzip
    ox
    btop
    fastfetchMinimal
  ];

  networking = {
    networkmanager.enable = false;
    useNetworkd = true;
    
    # Prevent conflict with systemd-networkd DHCP definitions below
    interfaces.${lanIf}.useDHCP = lib.mkForce false;
    
    firewall.allowedTCPPorts = [ nfsPort ];
  };

  systemd.network = {
    links."10-${lanIf}" = {
      matchConfig.Name = lanIf;
      linkConfig.WakeOnLan = "magic";
    };

    networks."10-lan" = {
      matchConfig.Name = lanIf;
      networkConfig = {
        DHCP = "ipv4"; # Explicit IPv4 to avoid IPv6 timeouts
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
    };

    wait-online = {
      enable = true;
      timeout = 30;
      # Strict requirement: interface must have routes (internet ready)
      extraArgs = [ "--interface=${lanIf}:routable" ];
    };
  };

  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  users.users.${mainUser}.extraGroups = [ "docker" ];

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
      ports = [ sshPort ];
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
          /mnt/storage ${tailscaleCidr}(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash,all_squash,anonuid=1001,anongid=1500)
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

    # Headless Optimizations
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
