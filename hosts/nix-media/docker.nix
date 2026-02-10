{
  pkgs,
  lib,
  config,
  mainUser,
  ...
}:

let
  # --- HOST CONFIGURATION ---
  # Hardware-specific GIDs (verify with `getent group render | cut -d: -f3`)
  renderGid = "303";
  videoGid = "26";

  # ID Mapping from Media Role
  uid = toString config.roles.media.nfsAnonUid;
  gid = toString config.roles.media.nfsAnonGid;

  # Service Configuration
  tz = config.core.locale.timeZone; # Use system timezone
  
  images = {
    jellyfin = "lscr.io/linuxserver/jellyfin:latest";
    audiobookshelf = "ghcr.io/advplyr/audiobookshelf:latest";
    cadvisor = "gcr.io/cadvisor/cadvisor:latest";
  };
  
  dockerNetwork = {
    name = "jellyfin";
    subnet = "172.18.0.0/16";
  };

  storagePath = "/mnt/storage";
  dockerPath = "/home/${mainUser}/docker";
  jellyfinCachePath = "/var/cache/jellyfin";
in
{
  assertions = [
    {
      assertion = renderGid != "REPLACE_ME";
      message = "Docker Config Error: Set 'renderGid' in hosts/nix-media/docker.nix";
    }
    # Removed UID assertion: Logic now sourced directly from trusted role config
  ];

  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        flags = [ "--all" "--force" ];
      };
      daemon.settings."metrics-addr" = "127.0.0.1:9323";
    };

    oci-containers = {
      backend = "docker";
      containers = {
        jellyfin = {
          autoStart = true;
          image = images.jellyfin;
          environment = {
            DOCKER_MODS = "ghcr.io/intro-skipper/intro-skipper-docker-mod";
            PGID = gid;
            PUID = uid;
            TZ = tz;
            LIBVA_DRIVER_NAME = "iHD";
            JELLYFIN_Network__BaseUrl = "/jellyfin";
          };
          volumes = [
            "${dockerPath}/jellyfin/config:/config"
            "${jellyfinCachePath}/cache:/cache"
            "${jellyfinCachePath}/transcode:/transcode"
            "${storagePath}/movies:/data/movies:ro"
            "${storagePath}/shows:/data/shows:ro"
            "${storagePath}/kinder:/data/kinder:ro"
          ];
          ports = [ "8096:8096" ];
          extraOptions = [
            "--network=${dockerNetwork.name}"
            "--device=/dev/dri:/dev/dri"
            "--group-add=${renderGid}"
            "--cpus=3.5"
            "--shm-size=256m"
            "--pids-limit=1000"
            "--health-cmd=curl -fsS http://localhost:8096/jellyfin/health || exit 1"
            "--health-interval=60s"
            "--health-retries=4"
            "--health-timeout=10s"
          ]
          ++ lib.optional (videoGid != "REPLACE_ME") "--group-add=${videoGid}";
        };

        audiobookshelf = {
          autoStart = true;
          image = images.audiobookshelf;
          environment = {
            AUDIOBOOKSHELF_UID = uid;
            AUDIOBOOKSHELF_GID = gid;
            TZ = tz;
          };
          volumes = [
            "${dockerPath}/audiobookshelf/config:/config"
            "${dockerPath}/audiobookshelf/metadata:/metadata"
            "${storagePath}/audiobooks:/audiobooks:ro"
            "${storagePath}/podcasts:/podcasts:ro"
          ];
          ports = [ "13378:80" ];
          extraOptions = [
            "--network=${dockerNetwork.name}"
            "--memory=512m"
            "--cpus=0.5"
            "--pids-limit=100"
            "--health-cmd=curl -fsS http://localhost/ping || exit 1"
            "--health-interval=60s"
            "--health-retries=3"
          ];
        };

        cadvisor = {
          autoStart = true;
          image = images.cadvisor;
          volumes = [
            "/:/rootfs:ro"
            "/var/run:/var/run:ro"
            "/sys:/sys:ro"
            "/var/lib/docker/:/var/lib/docker:ro"
            "/dev/disk/:/dev/disk:ro"
          ];
          ports = [ "127.0.0.1:8080:8080" ];
          extraOptions = [
            "--device=/dev/kmsg"
            "--memory=256m"
            "--cpus=0.25"
            "--pids-limit=75"
          ];
        };
      };
    };
  };

  fileSystems."${jellyfinCachePath}" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=2G"
      "mode=0755"
      "uid=${uid}"
      "gid=${gid}"
      "noatime"
      "nosuid"
      "nodev"
    ];
  };

  systemd.tmpfiles.rules = [
    # Note: Using mainUser/group names for readability; ownership aligns with IDs above
    "d ${jellyfinCachePath} 0755 ${mainUser} ${mainUser} - -"
    "d ${jellyfinCachePath}/cache 0755 ${mainUser} ${mainUser} - -"
    "d ${jellyfinCachePath}/transcode 0755 ${mainUser} ${mainUser} - -"
  ];

  systemd = {
    services = {
      "docker-network-jellyfin" = {
        description = "Ensure Docker network '${dockerNetwork.name}' exists";
        after = [ "docker.service" "docker.socket" ];
        requires = [ "docker.service" ];
        before = [ "docker-jellyfin.service" "docker-audiobookshelf.service" ];
        requiredBy = [ "docker-jellyfin.service" "docker-audiobookshelf.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.docker ];
        script = ''
          if ! docker network inspect "${dockerNetwork.name}" >/dev/null 2>&1; then
            docker network create "${dockerNetwork.name}" --subnet="${dockerNetwork.subnet}"
          fi
        '';
      };

      # Resource limits only - cleanup handled by oci-containers
      "docker-jellyfin".serviceConfig = {
        IOWeight = 8000;
        CPUWeight = 1000;
        OOMScoreAdjust = -500;
      };

      "docker-audiobookshelf".serviceConfig = {
        IOWeight = 100;
        CPUWeight = 100;
        OOMScoreAdjust = 500;
      };

      "docker-cadvisor".serviceConfig = {
        CPUWeight = 50;
        OOMScoreAdjust = 700;
      };

      "docker-image-refresh" = {
        description = "Pull latest Docker images and restart containers";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [ pkgs.docker pkgs.systemd ];
        script = ''
          set -e
          docker pull ${images.jellyfin}
          docker pull ${images.audiobookshelf}
          docker pull ${images.cadvisor}
          systemctl restart docker-jellyfin.service docker-audiobookshelf.service docker-cadvisor.service
          docker image prune -f
        '';
      };
    };

    timers."docker-image-refresh" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 03:00";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
