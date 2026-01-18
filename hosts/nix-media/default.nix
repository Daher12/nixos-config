
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ../../modules/core
    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
    ../../modules/hardware/intel-gpu.nix
  ];

  system.stateVersion = "24.05"; 

  # --- Boot & Kernel ---
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  
  # [OPTIMIZED] Media & Storage Tuning
  # N100 + 16GB RAM + HDD Storage Strategy
  boot.kernel.sysctl = {
    # 1. Memory / Cache
    # Prefer RAM usage for apps to avoid OOM locks, while still allowing
    # the filesystem cache to grow for media libraries.
    "vm.swappiness" = 10; 
    "vm.vfs_cache_pressure" = 50; 

    # 2. Writeback Control
    # Cap dirty data at 512MB to force more frequent, smaller I/O flushes.
    # Mitigates the risk of massive multi-gigabyte write bursts that can 
    # lock up mechanical HDDs and cause system-wide stutter.
    "vm.dirty_background_bytes" = 134217728;  # 128 MiB
    "vm.dirty_bytes"            = 536870912;  # 512 MiB
    "vm.dirty_writeback_centisecs" = 200;     # 2s 

    # 3. File Watchers (Essential for *arr apps)
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 1024;

    # 4. Networking (Torrent Optimization)
    "net.core.somaxconn" = 4096;
    "net.ipv4.ip_local_port_range" = "10240 65535";
  };
  
  boot.kernelParams = [ "transparent_hugepage=madvise" ];

  # --- Hardware ---
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true; 
    enableVpl = true;    
    enableGuc = true;
  };

  # --- Networking ---
  # [PARITY] Wake-on-LAN support
  networking.interfaces.enp1s0.wakeOnLan.enable = true;
  networking.firewall.allowedTCPPorts = [ 2049 ]; 

  # --- Services ---
  services = {
    # [IMPROVED] Server-Optimized Journald
    # - Compress=yes enables compression (algorithm depends on systemd version)
    # - Cap size at 500M total
    # - Retention: 30 days (in seconds)
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=500M
      SystemMaxFileSize=50M
      MaxRetentionSec=2592000
      RateLimitInterval=30s
      RateLimitBurst=1000
    '';

    # Logrotate for legacy text logs
    logrotate.enable = true;

    # [PARITY] SSH Hardening
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

    # NFS Server (Strict v4 Only)
    rpcbind.enable = lib.mkForce false;

    nfs = {
      server = {
        enable = true;
        exports = ''
          /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,all_squash,anonuid=1000,anongid=100)
        '';
      };
      
      # [MODERN] Structured Settings
      # Explicitly disables NFSv3 and UDP via /etc/nfs.conf generation.
      # Note: Verify active listeners after deployment (ss -tlpn) to ensure cleanliness.
      settings.nfsd = {
        vers3 = "n";
        udp = "n";
      };
    };

    # Maintenance
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    thermald.enable = true;
  };

  # --- Auto Upgrade ---
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    allowReboot = false;
    flake = "github:daher12/nixos-config#nix-media"; 
    randomizedDelaySec = "45min";
  };

  # --- Features ---
  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };
  
  features.sops.enable = true;
  users.users.dk.extraGroups = [ "docker" ];
}
