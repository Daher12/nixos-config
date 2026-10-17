{
  pkgs,
  lib,
  config,
  ...
}:

let
  # --- Service Definitions (Single Source of Truth) ---
  # Ports come from roles.media.ports (shared with docker.nix binds and
  # monitoring.nix scrape targets); icon/title/description are caddy-local.
  services = {
    jellyfin = {
      port = config.roles.media.ports.jellyfin;
      icon = "play-circle";
      title = "Jellyfin";
      description = "Media streaming: Movies, TV, and Music";
    };
    audiobookshelf = {
      port = config.roles.media.ports.audiobookshelf;
      icon = "headphones";
      title = "Audiobookshelf";
      description = "Audiobooks and Podcast library";
    };
    grafana = {
      port = config.roles.media.ports.grafana;
      icon = "bar-chart";
      title = "Grafana";
      description = "System monitoring and metrics";
    };
  };

  # --- Template Injection ---
  landingPage = pkgs.replaceVars ./landing.html {
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
    if name == "grafana" then
      ''
        handle /${name}/* {
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      ''
    else
      ''
        handle /${name}/* {
          uri strip_prefix /${name}
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      '';
in
{
  services.caddy = {
    enable = true;
    user = "caddy";
    group = "caddy";

    # Hardcoded tailnet MagicDNS zone — breaks silently if the tailnet is
    # ever renamed (no clean eval-time source; accepted literal).
    virtualHosts."${config.networking.hostName}.tail6db26.ts.net".extraConfig = ''
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
