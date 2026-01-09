{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "24.05";

  # Boot
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_6_12;

    kernelParams = [ "transparent_hugepage=madvise" ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
    };

    supportedFilesystems = [ "ntfs" ];
  };

  # Localization
  core.locale = {
    timeZone = "Europe/Berlin";
    defaultLocale = "de_DE.UTF-8";
  };

  # Networking
  core.networking = {
    backend = "iwd";
    enablePowersave = false;
  };

  networking = {
    domain = "tail6db26.ts.net";
    interfaces.enp1s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [
      26
      2049
    ]; # SSH, NFS
  };

  # SSH
  services.openssh = {
    enable = true;
    ports = [ 26 ];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = [ "dk" ];
      UseDns = false;
      X11Forwarding = false;
      PermitRootLogin = "no";
    };
  };

  # Tailscale
  features.vpn.tailscale = {
    enable = true;
    routingFeatures = "server";
    trustInterface = true;
  };

  services.tailscale.extraUpFlags = [ "--accept-routes" ];

  # NFS
  services.nfs.server = {
    enable = true;
    # Read NFS exports from secrets file (create: see setup instructions)
    exports = builtins.readFile ./secrets/nfs-exports.txt;
  };

  # Caddy reverse proxy with full landing page
  services.caddy = {
    enable = true;
    virtualHosts."nix-media.tail6db26.ts.net".extraConfig = ''
      tls { get_certificate tailscale }
      header {
        X-Content-Type-Options "nosniff"
        -Server
      }
      
      @redirect_jellyfin path /jellyfin
      redir @redirect_jellyfin /jellyfin/ 308
      handle /jellyfin/* {
        uri strip_prefix /jellyfin
        reverse_proxy http://127.0.0.1:8096
      }
      
      @redirect_audiobookshelf path /audiobookshelf
      redir @redirect_audiobookshelf /audiobookshelf/ 308
      handle /audiobookshelf/* {
        reverse_proxy http://127.0.0.1:13378
      }
      
      @redirect_grafana path /grafana
      redir @redirect_grafana /grafana/ 308
      handle /grafana/* {
        reverse_proxy http://127.0.0.1:3001
      }
      
      handle / {
        root * /etc/caddy
        try_files /landing.html
        file_server
      }
    '';
  };

  services.tailscale.permitCertUid = "caddy";

  environment.etc."caddy/landing.html".text = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Nix Media Server</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
      <style>
        :root {
          --color-bg-primary: #ffffff; --color-bg-secondary: #f8fafc; --color-bg-card: #ffffff;
          --color-border: #e2e8f0; --color-border-hover: #3b82f6;
          --color-text-primary: #0f172a; --color-text-secondary: #64748b;
          --color-accent: #3b82f6; --color-accent-secondary: #14b8a6;
          --color-shadow: rgba(15, 23, 42, 0.1); --color-shadow-hover: rgba(59, 130, 246, 0.2);
          --color-status-online: #10b981;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --color-bg-primary: #0f172a; --color-bg-secondary: #1e293b; --color-bg-card: rgba(30, 41, 59, 0.6);
            --color-border: #334155; --color-text-primary: #f8fafc; --color-text-secondary: #94a3b8;
            --color-shadow: rgba(0, 0, 0, 0.3); --color-shadow-hover: rgba(59, 130, 246, 0.3);
          }
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--color-bg-primary); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 2rem; line-height: 1.5; }
        .container { max-width: 900px; width: 100%; }
        .header { text-align: center; margin-bottom: 3rem; }
        .logo { width: 64px; height: 64px; margin: 0 auto 1.5rem; background: linear-gradient(135deg, var(--color-accent), var(--color-accent-secondary)); border-radius: 16px; display: flex; align-items: center; justify-content: center; box-shadow: 0 10px 40px -10px var(--color-accent); }
        .logo svg { width: 36px; height: 36px; stroke: white; stroke-width: 1.5; }
        h1 { font-size: 2rem; font-weight: 700; color: var(--color-text-primary); margin-bottom: 0.5rem; }
        .subtitle { color: var(--color-text-secondary); font-size: 1.125rem; }
        .services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-bottom: 3rem; }
        .service-card { background: var(--color-bg-card); border: 1px solid var(--color-border); border-radius: 16px; padding: 2rem; text-decoration: none; transition: all 0.2s ease; display: flex; flex-direction: column; backdrop-filter: blur(10px); }
        .service-card:hover { border-color: var(--color-border-hover); box-shadow: 0 20px 40px -20px var(--color-shadow-hover); transform: translateY(-2px); }
        .service-icon { width: 48px; height: 48px; background: var(--color-bg-secondary); border-radius: 12px; display: flex; align-items: center; justify-content: center; margin-bottom: 1.25rem; }
        .service-icon svg { width: 24px; height: 24px; stroke: var(--color-accent); }
        .service-title { font-size: 1.25rem; font-weight: 600; color: var(--color-text-primary); margin-bottom: 0.5rem; }
        .service-description { color: var(--color-text-secondary); line-height: 1.6; margin-bottom: 1.5rem; flex-grow: 1; }
        .service-status { display: flex; align-items: center; gap: 0.5rem; font-size: 0.875rem; color: var(--color-text-secondary); font-weight: 500; }
        .status-dot { width: 8px; height: 8px; background: var(--color-status-online); border-radius: 50%; animation: pulse 2s ease-in-out infinite; }
        @keyframes pulse { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.6; transform: scale(1.1); } }
        .status-text { text-transform: uppercase; letter-spacing: 0.05em; font-size: 0.75rem; font-weight: 600; }
        .footer { text-align: center; color: var(--color-text-secondary); font-size: 0.875rem; display: flex; align-items: center; justify-content: center; gap: 0.5rem; }
        .footer-divider { width: 4px; height: 4px; background: var(--color-text-secondary); border-radius: 50%; opacity: 0.5; }
        @media (max-width: 768px) { body { padding: 1.5rem; } .services-grid { grid-template-columns: 1fr; } .header { margin-bottom: 2rem; } .service-card { padding: 1.5rem; } }
        .service-card:focus { outline: 2px solid var(--color-accent); outline-offset: 2px; }
        @media (prefers-reduced-motion: reduce) { * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; } }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="2" y="3" width="20" height="4" rx="1"/><rect x="2" y="10" width="20" height="4" rx="1"/><rect x="2" y="17" width="20" height="4" rx="1"/>
              <circle cx="6" cy="5" r="0.5" fill="currentColor"/><circle cx="6" cy="12" r="0.5" fill="currentColor"/><circle cx="6" cy="19" r="0.5" fill="currentColor"/>
            </svg>
          </div>
          <h1>Nix Media Server</h1>
          <p class="subtitle">Your self-hosted media ecosystem</p>
        </div>
        <div class="services-grid">
          <a href="/jellyfin/" class="service-card">
            <div class="service-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="10 8 16 12 10 16 10 8" fill="currentColor"/></svg>
            </div>
            <h2 class="service-title">Jellyfin</h2>
            <p class="service-description">Stream your movies, TV shows, and music from anywhere</p>
            <div class="service-status">
              <span class="status-dot"></span>
              <span class="status-text">Online</span>
            </div>
          </a>
          <a href="/audiobookshelf/" class="service-card">
            <div class="service-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3v5Z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3v5Z"/></svg>
            </div>
            <h2 class="service-title">Audiobookshelf</h2>
            <p class="service-description">Listen to audiobooks and podcasts on all your devices</p>
            <div class="service-status">
              <span class="status-dot"></span>
              <span class="status-text">Online</span>
            </div>
          </a>
          <a href="/grafana/" class="service-card">
            <div class="service-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="13" width="4" height="8" rx="1"/><rect x="10" y="8" width="4" height="13" rx="1"/><rect x="17" y="4" width="4" height="17" rx="1"/></svg>
            </div>
            <h2 class="service-title">Grafana</h2>
            <p class="service-description">Monitor system health and container performance</p>
            <div class="service-status">
              <span class="status-dot"></span>
              <span class="status-text">Online</span>
            </div>
          </a>
        </div>
        <div class="footer">
          <span>Secured by Tailscale</span>
          <span class="footer-divider"></span>
          <span>Powered by NixOS</span>
        </div>
      </div>
    </body>
    </html>
  '';

  # Media server features
  features.media-server = {
    enable = true;
    dataDir = "/mnt/storage";
    jellyfin.enable = true;
    audiobookshelf.enable = true;
    cadvisor.enable = true;
  };

  # Monitoring
  features.monitoring-stack = {
    enable = true;
    intelGpuMetrics = true;
    alertmanager = {
      enable = true;
      webhookUrl = "http://127.0.0.1:9095/alert";
    };
    # Read Grafana admin password from secrets file (create: see setup instructions)
    grafana.adminPassword = lib.strings.removeSuffix "\n" (builtins.readFile ./secrets/grafana-password.txt);
  };

  # Notifications
  features.notifications = {
    enable = true;
    # Read ntfy topic from secrets file (create: echo "your-secret-topic" > ./secrets/ntfy-topic.txt)
    topic = lib.strings.removeSuffix "\n" (builtins.readFile ./secrets/ntfy-topic.txt);
    monitorServices = [
      "docker-jellyfin"
      "docker-audiobookshelf"
      "docker-cadvisor"
      "docker-network-jellyfin"
      "docker-image-refresh"
      "nixos-upgrade"
    ];
    alertmanagerBridge = true;
    smartdNotifications = true;
    bootNotification = true;
  };

  # Intel QSV
  features.intel-qsv = {
    enable = true;
    deviceId = "46d1";
  };

  # Journal limits
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemMaxFileSize=100M
    MaxRetentionSec=1month
    Compress=yes
  '';

  # Packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    xfsprogs
    ntfs3g
    mergerfs
    wget
    nfs-utils
    mosh
    ethtool
    btop
    smartmontools
    nvme-cli
    unrar
    unzip
    trash-cli
    docker-compose
    fastfetchMinimal
    gitMinimal
    yazi
    ox
    jq
  ];

  # Shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "agnoster";
    };
  };
  programs.zoxide.enable = true;
}
