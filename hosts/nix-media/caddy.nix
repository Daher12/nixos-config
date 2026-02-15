{ pkgs, lib, ... }:

let
  # --- Service Definitions (Single Source of Truth) ---
  services = {
    jellyfin = {
      port = 8096;
      icon = "play-circle";
      title = "Jellyfin";
      description = "Media streaming: Movies, TV, and Music";
    };
    audiobookshelf = {
      port = 13378;
      icon = "headphones";
      title = "Audiobookshelf";
      description = "Audiobooks and Podcast library";
    };
    grafana = {
      port = 3001;
      icon = "bar-chart";
      title = "Grafana";
      description = "System monitoring and metrics";
    };
  };

  # --- Template Injection ---
  # FIX: Replaced removed 'substituteAll' with 'replaceVars'
  landingPage = pkgs.replaceVars ./landing.html {
    # Generate JSON for the frontend
    servicesJson = builtins.toJSON (
      lib.mapAttrsToList (name: cfg: {
        inherit name;
        inherit (cfg) icon title description;
        url = "/${name}/";
      }) services
    );
  };

  # --- Caddy Config Generators ---
  mkRedirect = name: _: ''
    @redirect_${name} path /${name}
    redir @redirect_${name} /${name}/ 308
  '';

  mkHandle =
    name: cfg:
    # Jellyfin requires strip_prefix for subpath hosting if baseurl isn't set
    if name == "jellyfin" then
      ''
        handle /${name}/* {
          uri strip_prefix /${name}
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      ''
    else
      ''
        handle /${name}/* {
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      '';
in
{
  services.caddy = {
    enable = true;
    user = "caddy";
    group = "caddy";

    # VERIFY: Ensure hostname matches your Tailscale domain
    virtualHosts."nix-media.tail6db26.ts.net".extraConfig = ''
      tls { get_certificate tailscale }
      header {
        X-Content-Type-Options "nosniff"
        -Server
      }

      # Generated Redirects (e.g., /jellyfin -> /jellyfin/)
      ${lib.concatMapStrings (name: mkRedirect name services.${name}) (lib.attrNames services)}

      # Generated Proxy Handles
      ${lib.concatMapStrings (name: mkHandle name services.${name}) (lib.attrNames services)}

      # Default: Landing Dashboard
      handle / {
        root * /etc/caddy
        try_files /landing.html
        file_server
      }
    '';
  };

  # Deploy the templated HTML to /etc/caddy
  environment.etc."caddy/landing.html".source = landingPage;

  # Allow Caddy to read Tailscale certs
  services.tailscale.permitCertUid = "caddy";

  systemd.services.caddy.serviceConfig = {
    LogsDirectory = "caddy";
    Restart = "on-failure";
    RestartSec = "5s";
  };
}
