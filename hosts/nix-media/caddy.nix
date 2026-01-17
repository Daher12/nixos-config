{ config, pkgs, lib, ... }:

let
  # --- Service Definitions for Dashboard ---
  services = {
    jellyfin = {
      port = 8096;
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="10 8 16 12 10 16 10 8" fill="currentColor"/></svg>'';
      title = "Jellyfin";
      description = "Stream your movies, TV shows, and music from anywhere";
    };
    audiobookshelf = {
      port = 13378;
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3v5Z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3v5Z"/></svg>'';
      title = "Audiobookshelf";
      description = "Listen to audiobooks and podcasts on all your devices";
    };
    grafana = {
      port = 3001;
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="13" width="4" height="8" rx="1"/><rect x="10" y="8" width="4" height="13" rx="1"/><rect x="17" y="4" width="4" height="17" rx="1"/></svg>'';
      title = "Grafana";
      description = "Monitor system health and container performance";
    };
  };

  # --- Caddy Configuration Generators ---
  mkRedirect = name: cfg: ''
    @redirect_${name} path /${name}
    redir @redirect_${name} /${name}/ 308
  '';

  mkHandle = name: cfg: 
    if name == "jellyfin" then ''
      handle /${name}/* {
        uri strip_prefix /${name}
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      }
    '' else ''
      handle /${name}/* {
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      }
    '';

  mkServiceCard = name: cfg: ''
    <a href="/${name}/" class="service-card">
      <div class="service-icon">${cfg.icon}</div>
      <h2 class="service-title">${cfg.title}</h2>
      <p class="service-description">${cfg.description}</p>
      <div class="service-status">
        <span class="status-dot"></span>
        <span class="status-text">Online</span>
      </div>
    </a>
  '';

  # --- Full HTML Landing Page ---
  landingPage = pkgs.writeText "landing.html" ''
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
          --color-bg-primary: #ffffff;
          --color-bg-secondary: #f8fafc; --color-bg-card: #ffffff;
          --color-border: #e2e8f0; --color-border-hover: #3b82f6;
          --color-text-primary: #0f172a; --color-text-secondary: #64748b;
          --color-accent: #3b82f6; --color-accent-secondary: #14b8a6;
          --color-shadow: rgba(15, 23, 42, 0.1); --color-shadow-hover: rgba(59, 130, 246, 0.2);
          --color-status-online: #10b981;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --color-bg-primary: #0f172a;
            --color-bg-secondary: #1e293b; --color-bg-card: rgba(30, 41, 59, 0.6);
            --color-border: #334155; --color-text-primary: #f8fafc; --color-text-secondary: #94a3b8;
            --color-shadow: rgba(0, 0, 0, 0.3);
            --color-shadow-hover: rgba(59, 130, 246, 0.3);
          }
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--color-bg-primary);
          min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 2rem; line-height: 1.5; }
        .container { max-width: 900px; width: 100%; }
        .header { text-align: center; margin-bottom: 3rem; }
        .logo { width: 64px; height: 64px; margin: 0 auto 1.5rem;
          background: linear-gradient(135deg, var(--color-accent), var(--color-accent-secondary)); border-radius: 16px; display: flex; align-items: center; justify-content: center; box-shadow: 0 10px 40px -10px var(--color-accent); }
        .logo svg { width: 36px; height: 36px; stroke: white; stroke-width: 1.5; }
        h1 { font-size: 2rem; font-weight: 700; color: var(--color-text-primary); margin-bottom: 0.5rem; }
        .subtitle { color: var(--color-text-secondary); font-size: 1.125rem; }
        .services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-bottom: 3rem; }
        .service-card { background: var(--color-bg-card); border: 1px solid var(--color-border); border-radius: 16px; padding: 2rem;
          text-decoration: none; transition: all 0.2s ease; display: flex; flex-direction: column; backdrop-filter: blur(10px); }
        .service-card:hover { border-color: var(--color-border-hover); box-shadow: 0 20px 40px -20px var(--color-shadow-hover); transform: translateY(-2px); }
        .service-icon { width: 48px; height: 48px; background: var(--color-bg-secondary); border-radius: 12px; display: flex;
          align-items: center; justify-content: center; margin-bottom: 1.25rem; }
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
          ${lib.concatMapStrings (name: mkServiceCard name services.${name}) (lib.attrNames services)}
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
in
{
  services.caddy = {
    enable = true;
    user = "caddy";
    group = "caddy";
    
    # Configure Virtual Host with Tailscale DNS
    virtualHosts."nix-media.tail6db26.ts.net".extraConfig = ''
      tls { get_certificate tailscale }
      header {
        X-Content-Type-Options "nosniff"
        -Server
      }
      
      # Generated Redirects (e.g., /jellyfin -> /jellyfin/)
      ${lib.concatMapStrings (name: mkRedirect name services.${name}) (lib.attrNames services)}
      
      # Generated Reverse Proxies
      ${lib.concatMapStrings (name: mkHandle name services.${name}) (lib.attrNames services)}
      
      # Root Handle: Serve Landing Page
      handle / {
        root * /etc/caddy
        try_files /landing.html
        file_server
      }
    '';
  };

  # Provision the HTML file
  environment.etc."caddy/landing.html".source = landingPage;

  # Allow Caddy to access Tailscale certificate socket
  systemd.services.caddy.serviceConfig = {
    Group = "tailscale";
    LogsDirectory = "caddy";
    Restart = "on-failure";
    RestartSec = "5s";
  };
}
