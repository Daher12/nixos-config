{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.media-server;
in
{
  options.features.media-server = {
    enable = lib.mkEnableOption "media server stack (Jellyfin, Audiobookshelf, cAdvisor)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage";
      description = "Root directory for media files";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/docker-media";
      description = "Root directory for service configurations";
    };

    jellyfin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Jellyfin media server";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8096;
        description = "Jellyfin HTTP port";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall for Jellyfin";
      };
    };

    audiobookshelf = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Audiobookshelf";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 13378;
        description = "Audiobookshelf HTTP port";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall for Audiobookshelf";
      };
    };

    cadvisor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable cAdvisor for container monitoring";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "cAdvisor metrics port";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
      daemon.settings = {
        metrics-addr = "127.0.0.1:9323";
        experimental = true;
        live-restore = false;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0755 root root - -"
      "d ${cfg.configDir}/jellyfin 0755 root root - -"
      "d ${cfg.configDir}/audiobookshelf 0755 root root - -"
    ];

    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = lib.mkMerge [
      (lib.mkIf cfg.jellyfin.enable {
        jellyfin = {
          image = "jellyfin/jellyfin:latest";
          autoStart = true;
          ports = [ "127.0.0.1:${toString cfg.jellyfin.port}:8096" ];
          volumes = [
            "${cfg.configDir}/jellyfin/config:/config"
            "${cfg.configDir}/jellyfin/cache:/cache"
            "${cfg.dataDir}:/media:ro"
          ];
          environment = {
            TZ = config.time.timeZone or "UTC";
            JELLYFIN_PublishedServerUrl =
              if config.networking.domain != null then
                "https://${config.networking.hostName}.${config.networking.domain}"
              else
                "http://${config.networking.hostName}";
          };
          extraOptions = [
            "--device=/dev/dri/renderD128:/dev/dri/renderD128"
            "--group-add=video"
            "--network=jellyfin"
            "--pull=newer"
          ];
        };
      })

      (lib.mkIf cfg.audiobookshelf.enable {
        audiobookshelf = {
          image = "ghcr.io/advplyr/audiobookshelf:latest";
          autoStart = true;
          ports = [ "127.0.0.1:${toString cfg.audiobookshelf.port}:80" ];
          volumes = [
            "${cfg.configDir}/audiobookshelf/config:/config"
            "${cfg.configDir}/audiobookshelf/metadata:/metadata"
            "${cfg.dataDir}:/media:ro"
          ];
          environment = {
            TZ = config.time.timeZone or "UTC";
          };
          extraOptions = [
            "--network=jellyfin"
            "--pull=newer"
          ];
        };
      })

      (lib.mkIf cfg.cadvisor.enable {
        cadvisor = {
          image = "gcr.io/cadvisor/cadvisor:latest";
          autoStart = true;
          ports = [ "127.0.0.1:${toString cfg.cadvisor.port}:8080" ];
          volumes = [
            "/:/rootfs:ro"
            "/var/run:/var/run:ro"
            "/sys:/sys:ro"
            "/var/lib/docker:/var/lib/docker:ro"
            "/dev/disk:/dev/disk:ro"
          ];
          extraOptions = [
            "--privileged"
            "--device=/dev/kmsg"
            "--pull=newer"
          ];
        };
      })
    ];

    systemd.services.docker-image-refresh = {
      description = "Pull latest Docker images";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "docker-pull" ''
          ${pkgs.docker}/bin/docker pull jellyfin/jellyfin:latest
          ${pkgs.docker}/bin/docker pull ghcr.io/advplyr/audiobookshelf:latest
          ${pkgs.docker}/bin/docker pull gcr.io/cadvisor/cadvisor:latest
        '';
      };
      unitConfig.OnFailure = "ntfy-failure@%n.service";
    };

    systemd.timers.docker-image-refresh = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 03:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    systemd.services.docker-network-jellyfin = {
      description = "Create Docker network for media services";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "create-docker-network" ''
          ${pkgs.docker}/bin/docker network inspect jellyfin >/dev/null 2>&1 || \
            ${pkgs.docker}/bin/docker network create jellyfin
        '';
      };
      unitConfig.OnFailure = "ntfy-failure@%n.service";
    };

    networking.firewall.allowedTCPPorts = lib.mkMerge [
      (lib.mkIf (cfg.jellyfin.enable && cfg.jellyfin.openFirewall) [ cfg.jellyfin.port ])
      (lib.mkIf (cfg.audiobookshelf.enable && cfg.audiobookshelf.openFirewall) [
        cfg.audiobookshelf.port
      ])
    ];
  };
}
