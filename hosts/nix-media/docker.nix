{
  pkgs,
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
  tz = config.time.timeZone;

  images = {
    # :latest + the weekly docker-image-refresh timer = auto-updates every
    # Sunday 03:00, including future X-major releases (accepted 2026-09-19).
    # The DB has been on the 12.x schema since 2026-09-11 — 10.x is NOT a
    # rollback path. X-major releases carry breaking changes + a manual
    # upgrade process (backup first!); Y releases are bugfix-only per
    # Jellyfin's versioning policy.
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
  jellyfinCachePath = "/var/cache/jellyfin"; # Now 6GB tmpfs
in
{
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        flags = [
          "--all"
          "--force"
        ];
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
            # 2026-09-19: DOCKER_MODS (intro-skipper docker-mod) removed.
            # ghcr.io answers 403 DENIED for the mod image since ~2026-09-12
            # — the project dropped it; the install method is now the
            # version-aware plugin repository manifest
            # (https://intro-skipper.org/manifest.json). The plugin itself
            # persists in /config/data/plugins ("Intro Skipper" 12.0.4.0,
            # matching the pinned Jellyfin 12.0) and loads without the mod;
            # the dead env only logged "(ERROR) OFFLINE" at every container
            # start. When unpinning to 12.1+: update the plugin via its
            # repository in the dashboard.
            PGID = gid;
            PUID = uid;
            TZ = tz;
            LIBVA_DRIVER_NAME = "iHD";
            JELLYFIN_Network__BaseUrl = "/jellyfin";
            # N100 QSV tuning for 4K transcodes
            JELLYFIN_FFmpeg__probesize = "100000000";
            JELLYFIN_FFmpeg__analyzeduration = "100000000";
            # Force tone mapping via OpenCL (N100 has limited 10-bit support)
            NEOReadDebugKeys = "1";
          };
          volumes = [
            "${dockerPath}/jellyfin/config:/config"
            "${jellyfinCachePath}/cache:/config/cache"
            "${jellyfinCachePath}/transcode:/config/transcode"
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
            "--shm-size=2g"
            "--pids-limit=1000"
            # Server serves at / (BaseUrl env is not applied; Caddy's
            # strip_prefix makes /jellyfin/ work) — probe the root health
            # endpoint, not /jellyfin/health (always 404 → permanent
            # "unhealthy" badge).
            "--health-cmd=curl -fsS http://localhost:8096/health || exit 1"
            "--health-interval=60s"
            "--health-retries=4"
            "--health-timeout=10s"
            "--group-add=${videoGid}"
          ];
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
          ports = [ "127.0.0.1:13378:80" ];
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
      "size=6G" # 4K transcodes need ~2-3GB per session
      "mode=0755"
      "uid=${uid}"
      "gid=${gid}"
      "noatime"
      "nosuid"
      "nodev"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${jellyfinCachePath} 0755 ${uid} ${gid} - -"
    "d ${jellyfinCachePath}/cache 0755 ${uid} ${gid} - -"
    "d ${jellyfinCachePath}/transcode 0755 ${uid} ${gid} - -"
  ];

  systemd = {
    services = {
      "docker-network-jellyfin" = {
        description = "Ensure Docker network '${dockerNetwork.name}' exists";
        after = [
          "docker.service"
          "docker.socket"
        ];
        requires = [ "docker.service" ];
        before = [
          "docker-jellyfin.service"
          "docker-audiobookshelf.service"
        ];
        requiredBy = [
          "docker-jellyfin.service"
          "docker-audiobookshelf.service"
        ];
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
        StartLimitBurst = 10;
        StartLimitIntervalSec = "5min";
      };

      "docker-audiobookshelf".serviceConfig = {
        IOWeight = 100;
        CPUWeight = 100;
        OOMScoreAdjust = 500;
        StartLimitBurst = 10;
        StartLimitIntervalSec = "5min";
      };

      "docker-cadvisor".serviceConfig = {
        CPUWeight = 50;
        OOMScoreAdjust = 700;
        StartLimitBurst = 10;
        StartLimitIntervalSec = "5min";
      };

      "docker-image-refresh" = {
        description = "Pull latest Docker images and restart containers";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.docker
          pkgs.systemd
        ];
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
