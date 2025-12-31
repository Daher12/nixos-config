{ config, pkgs, lib, ... }:

{
  # ===========================================================================
  # LOCALIZATION & CONSOLE
  # ===========================================================================
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console = {
    earlySetup = true;
    font = "ter-v16n";
    packages = [ pkgs.terminus_font ];
  };

  # ===========================================================================
  # FILESYSTEM & BUILD PERFORMANCE
  # ===========================================================================
  
  # 1. Mount /tmp in RAM (Tmpfs)
  boot.tmp = {
    useTmpfs = true;
    # If you have 16GB RAM, 75-80% is safe. If 32GB, 50% is plenty.
    # Nix will clean this up automatically on reboot.
    tmpfsSize = "80%";
    cleanOnBoot = true;
  };

  
  # ===========================================================================
  # BUILD & PACKAGE MANAGEMENT
  # ===========================================================================
  
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    
    # Lix Optimierungen
    eval-cache = true;
    warn-dirty = false;
    
    # Build Ressourcen
    max-jobs = "auto";
    cores = 0;
    trusted-users = [ "root" "dk" ];
    
    # Sandbox
    sandbox = true;
    sandbox-fallback = false;
    
    # Store Limits
    min-free = 5368709120;  # 5GB
    max-free = 21474836480; # 20GB

    # Binary Caches
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cache.lix.systems"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
    ];

    # Network
    fallback = true;
    http-connections = 128;
    connect-timeout = 5;
    download-attempts = 3;
    stalled-download-timeout = 300;

    keep-derivations = false;
    keep-outputs = false;
    
    # Ccache Sandbox Access
    extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
  };

  # GC & Optimise
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
  
  environment.systemPackages = [ pkgs.cachix ];

  # Ccache Configuration
  programs.ccache = {
    enable = true;
    cacheDir = "/var/cache/ccache";
    packageNames = [];
  };
  
  systemd.tmpfiles.rules = [
    "d /var/cache/ccache 0770 root nixbld -"
    "h /var/cache/ccache - - - - +C"
  ];

  environment.variables = {
    CCACHE_COMPRESS = "1";
    CCACHE_COMPRESSLEVEL = "6";
    CCACHE_MAXSIZE = "25G";
    CCACHE_UMASK = "002";
    CCACHE_SLOPPINESS = "include_file_mtime,include_file_ctime,time_macros";
    CCACHE_DIRECT = "true";
  };

  # ===========================================================================
  # BOOT OPTIMIZATIONS
  # ===========================================================================
  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    initrd.systemd.enable = true;
    
    initrd.compressor = "zstd";
    initrd.compressorArgs = [ "-3" "-T0" ];
    
    initrd.availableKernelModules = [ ];
    
    plymouth = {
      enable = true;
      theme = "bgrt";
    };

    kernelParams = [
      "quiet"
      "splash"
      "vt.global_cursor_default=0"
      "systemd.show_status=false"
      "udev.log_level=3"
      "loglevel=3"
      "systemd.log_level=warning"
      "nowatchdog"
      "nmi_watchdog=0"
    ];

    kernel.sysctl = {
      "vm.swappiness" = 100;
      "vm.watermark_boost_factor" = 0;
      "vm.vfs_cache_pressure" = 100;
      "vm.page-cluster" = 0;
      "vm.max_map_count" = 1048576;
      "vm.dirty_bytes" = 268435456;
      "vm.dirty_background_bytes" = 134217728;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.dirty_expire_centisecs" = 3000;
      
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.netdev_max_backlog" = 32768;
      "net.core.rmem_max" = 67108864;
      "net.core.wmem_max" = 67108864;
      "net.ipv4.tcp_rmem" = "4096 131072 67108864";
      "net.ipv4.tcp_wmem" = "4096 131072 67108864";
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_low_latency" = 1;
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_notsent_lowat" = 16384;
      
      "fs.file-max" = 2097152;
      "fs.inotify.max_user_watches" = 524288;
    };
    
    kernelModules = [ "tcp_bbr" ];

    loader.systemd-boot.enable = lib.mkForce false;
    loader.efi.canTouchEfiVariables = true;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  # ZRAM
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 100;
    priority = 10;
    swapDevices = 1;
  };

  # ===========================================================================
  # HARDWARE & CONNECTIVITY
  # ===========================================================================
  
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
    };
  };

  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      wifi.powersave = true;
      dns = "systemd-resolved";
    };
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  services.resolved = {
    enable = true;
    extraConfig = ''
      DNSStubListener=yes
      Cache=yes
      CacheFromLocalhost=yes
      DNSOverTLS=no
    '';
  };

  networking.nameservers = [ ];
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # ===========================================================================
  # TOOLS & SERVICES
  # ===========================================================================
  programs.fish.enable = true;
  programs.adb.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 1024;
        default.clock.min-quantum = 512;
        default.clock.max-quantum = 2048;
      };
    };
  };

  services.libinput.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  
  # Systemd Optimizations
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    DefaultTimeoutStartSec = "30s";
  };

  systemd.services = {
    nix-daemon.serviceConfig = {
      Slice = "background.slice";
      Nice = 10;
      CPUWeight = 50;
      IOWeight = 50;
      IOSchedulingClass = "best-effort";
      MemoryHigh = "80%";
      CPUQuota = "200%";
    };
    NetworkManager-wait-online.enable = false;
  };

  # ===========================================================================
  # USERS & DEBLOAT
  # ===========================================================================
  
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  # FIX: 'nixpkgs.config' removed here because it's set in flake.nix
  
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
  
  services.fwupd.enable = true;
  systemd.coredump.enable = false;

  users.users.dk = {
    isNormalUser = true;
    description = "David";
    group = "dk";
    extraGroups = [ 
      "networkmanager" "wheel" "video" "audio" 
      "input" "adbusers" "render" "libvirtd" 
    ];
  };
  users.groups.dk = {};
  
  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults timestamp_timeout=30
      Defaults !tty_tickets
    '';
  };
}
