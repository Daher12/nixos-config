{ pkgs, lib, ... }:

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

  # --- Boot & Kernel ---
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    # [OPTIMIZED] Media & Storage Tuning
    # N100 + 16GB RAM + HDD Storage Strategy
    kernel.sysctl = {
      # 1. Memory / Cache
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;

      # 2. Writeback Control
      "vm.dirty_background_bytes" = 134217728; # 128 MiB
      "vm.dirty_bytes" = 536870912; # 512 MiB

      # [FIX] Force override of global default (1500)
      "vm.dirty_writeback_centisecs" = lib.mkForce 200; # 2s

      # 3. File Watchers (Essential for *arr apps)
      # [FIX] Force override of global default (524288)
      "fs.inotify.max_user_watches" = lib.mkForce 1048576;
      "fs.inotify.max_user_instances" = 1024;

      # 4. Networking (Torrent Optimization)
      "net.core.somaxconn" = 4096;
      "net.ipv4.ip_local_port_range" = "10240 65535";
    };

    kernelParams = [ "transparent_hugepage=madvise" ];
  };

  # --- Hardware ---
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  # --- Networking ---
  networking = {
    # [PARITY] Wake-on-LAN support
    interfaces.enp1s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [ 2049 ];
  };

  # --- Services ---
  services = {
    # [IMPROVED] Server-Optimized Journald
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
          /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash)
        '';
      };

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

  # --- System & Updates ---
  system = {
    stateVersion = "24.05";

    autoUpgrade = {
      enable = true;
      dates = "04:00";
      allowReboot = false;
      flake = "github:daher12/nixos-config#nix-media";
      randomizedDelaySec = "45min";
    };
  };

  # --- Features ---
  features = {
    vpn.tailscale = {
      enable = true;
      trustInterface = true;
      routingFeatures = "server";
    };

    sops.enable = true;
  };

  environment.systemPackages = [
    pkgs.mergerfs
  ];

  users.users.dk.extraGroups = [ "docker" ];

  # --- Headless Optimizations ---
  # Override desktop services enabled by modules/core
  services.pipewire.enable = lib.mkForce false;
  security.rtkit.enable = lib.mkForce false; # DBus RealtimeKit (for audio)
  services.libinput.enable = lib.mkForce false; # Input device handling
  programs.adb.enable = lib.mkForce false; # Android Debug Bridge

  # Explicitly disable other desktop features
  services.pulseaudio.enable = false;
  services.udisks2.enable = false;
  services.flatpak.enable = false;

}
