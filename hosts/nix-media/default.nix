{
  pkgs,
  lib,
  config,
  mainUser,
  ...
}:

let
  lanIf = "enp1s0";
  sshPort = 26;
  nfsPort = 2049;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/media.nix

    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix
    ./mnamer.nix
  ];

  # --- Core Configuration ---
  core = {
    boot.tmpfs = {
      enable = true;
      size = "80%";
    };
    
    nix.gc = {
     automatic = true;
     dates = "Sun 03:15";
     flags = "--delete-older-than 60d";
    };
    
    users.defaultShell = "zsh";
    sysctl.optimizeForServer = true;
  };

  roles.media = {
    enable = true;
    nfsAnonUid = 1001;
    nfsAnonGid = 982;
  };

  system.stateVersion = "24.05";
  hardware.isPhysical = true;

  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];
    kernel.sysctl."vm.dirty_writeback_centisecs" = 200;
    tmp.cleanOnBoot = true;
  };

  # Features enabled via standardized options
  features = {
    sops.enable = true;

    vpn.tailscale = {
      enable = true;
      trustInterface = true;
      routingFeatures = "server";
    };

    mnamer = {
      enable = true;

      paths = {
        downloads = "/mnt/storage/downloads";
        movies = "/mnt/storage/movies";
        shows = "/mnt/storage/shows";
      };

      formats = {
        movie = "{name} ({year})/{name} ({year}).{extension}";
        episode = "{series}/Season {season:02}/{series} - S{season:02}E{episode:02} - {title}.{extension}";
      };

      ignore = [
        ".*sample.*"
        "^RARBG.*"
        ".*\\.part[0-9]+.*"
        ".*\\btrailer\\b.*"
        ".*\\bnfo\\b.*"
      ];

      extraSettings = {
        hits = 8;
      };

      extraCliArgs = [ "--no-style" ];
    };
  };

  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true; # Critical for HDR→SDR tone mapping
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
    interfaces.${lanIf}.useDHCP = lib.mkForce false;

    firewall = {
      allowedTCPPorts = [ ];
      # Close global access; roles.media handles exports, we allow traffic here
      interfaces."tailscale0".allowedTCPPorts = [ nfsPort ];
    };
  };

  systemd.network = {
    links."10-${lanIf}" = {
      matchConfig.Name = lanIf;
      linkConfig.WakeOnLan = "magic";
    };
    networks."10-lan" = {
      matchConfig.Name = lanIf;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
    };
    wait-online = {
      enable = true;
      timeout = 30;
      extraArgs = [ "--interface=${lanIf}:routable" ];
    };
  };

  users.users.${mainUser} = {
    uid = config.roles.media.nfsAnonUid;
    extraGroups = [ "docker" ];
  };

  users.groups.${mainUser}.gid = config.roles.media.nfsAnonGid;

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
    fstrim = {
      enable = true;
      interval = "weekly";
    };

    thermald.enable = true;
    pipewire.enable = false;
    pulseaudio.enable = false;
  };

  security.rtkit.enable = false;
}
