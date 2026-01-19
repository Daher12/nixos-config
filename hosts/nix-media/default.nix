{
  pkgs,
  lib,
  mainUser, # Injected via specialArgs from flake.nix
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix

    # Feature modules
    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
    ../../modules/hardware/intel-gpu.nix
  ];

  # ---------------------------------------------------------------------------
  # Boot & Kernel Tuning
  # ---------------------------------------------------------------------------
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    #    kernelPackages = pkgs.linuxPackages_6_12;

    kernelParams = [
      "transparent_hugepage=madvise"
      #      "i915.force_probe=46d1"
    ];

    #    supportedFilesystems = [ "ntfs" ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_background_bytes" = 134217728;
      "vm.dirty_bytes" = 536870912;
      "vm.dirty_writeback_centisecs" = lib.mkForce 200;
      "fs.inotify.max_user_watches" = lib.mkForce 1048576;
      "fs.inotify.max_user_instances" = 1024;
      "net.core.somaxconn" = 4096;
      "net.ipv4.ip_local_port_range" = "10240 65535";
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
    #    ntfs3g
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
  ];

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking = {
    interfaces.enp1s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [ 2049 ]; # NFS
  };

  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  # ---------------------------------------------------------------------------
  # Shell & User Environment
  # ---------------------------------------------------------------------------
  # [FIXED] Merged all 'programs' definitions into one block
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      histSize = 10000;
      ohMyZsh = {
        enable = true;
        theme = "agnoster";
      };
    };
    zoxide.enable = true;
    adb.enable = lib.mkForce false; # Headless optimization
  };

  users.users.${mainUser} = {
    extraGroups = [ "docker" ];
    shell = pkgs.zsh;
  };

  # ---------------------------------------------------------------------------
  # Services
  # ---------------------------------------------------------------------------
  # [FIXED] Merged all 'services' definitions into one block
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

    # Headless Optimizations (Merged here to satisfy linter)
    pipewire.enable = lib.mkForce false;
    pulseaudio.enable = false;
    libinput.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;
    flatpak.enable = false;
    fwupd.enable = lib.mkForce false;
  };

  # ---------------------------------------------------------------------------
  # System Maintenance
  # ---------------------------------------------------------------------------
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

  features.sops.enable = true;
  security.rtkit.enable = lib.mkForce false;
}
