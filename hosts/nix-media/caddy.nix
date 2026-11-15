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
  # Services that CAN join the /<name>/ path scheme.
  proxiedServices = {
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

  # Services that cannot: Silo does not support sub-path hosting (upstream
  # docs: "use a dedicated hostname at its root"), so it gets its own HTTPS
  # listener on :siloHttps below, sharing the same hostname — and therefore
  # the same tailscale certificate, no second issuance. It still appears on
  # the landing page, with an absolute URL instead of a path.
  rootServices = {
    silo = {
      icon = "film";
      title = "Silo";
      description = "Media streaming (trial — A/B vs Jellyfin)";
      url = "https://${config.networking.hostName}.tail6db26.ts.net:${toString config.roles.media.ports.siloHttps}/";
    };
  };

  # Landing-page inventory = proxied + root services.
  services = proxiedServices // rootServices;

  # --- Template Injection ---
  landingPage = pkgs.replaceVars ./landing.html {
    servicesJson = builtins.toJSON (
      lib.mapAttrsToList (name: cfg: {
        inherit name;
        inherit (cfg) icon title description;
        url = cfg.url or "/${name}/";
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

    # Hardcoded tailnet MagicDNS zone — breaks silently if the tailnet is
    # ever renamed (no clean eval-time source; accepted literal).
    virtualHosts."${config.networking.hostName}.tail6db26.ts.net".extraConfig = ''
      tls { get_certificate tailscale }
      header {
        X-Content-Type-Options "nosniff"
        -Server
      }

      # Health probe for the Silo landing card: Silo itself cannot be
      # path-hosted (see rootServices), but exposing just its ready
      # endpoint under the main vhost keeps the status dot honest.
      handle /silo-health {
        rewrite * /api/v1/ready
        reverse_proxy http://127.0.0.1:${toString config.roles.media.ports.silo}
      }

      # Generated Redirects (e.g., /jellyfin -> /jellyfin/)
      ${lib.concatMapStrings (name: mkRedirect name proxiedServices.${name}) (
        lib.attrNames proxiedServices
      )}

      # Generated Proxy Handles
      ${lib.concatMapStrings (name: mkHandle name proxiedServices.${name}) (
        lib.attrNames proxiedServices
      )}

      # Default: Landing Dashboard
      handle / {
        root * /etc/caddy
        try_files /landing.html
        file_server
      }
    '';

    # Silo trial: root-path-only upstream on its own port, same hostname —
    # the tailscale cert is per-hostname, so no second issuance. Caddy
    # passes range requests and websockets by default (Silo seeking and
    # live updates need both).
    virtualHosts."${config.networking.hostName}.tail6db26.ts.net:${toString config.roles.media.ports.siloHttps}".extraConfig =
      ''
        tls { get_certificate tailscale }
        header {
          X-Content-Type-Options "nosniff"
          -Server
        }
        reverse_proxy http://127.0.0.1:${toString config.roles.media.ports.silo}
      '';
  };

  environment.etc."caddy/landing.html".source = landingPage;

  # Allow Caddy to read Tailscale certs
  services.tailscale.permitCertUid = "caddy";
}
