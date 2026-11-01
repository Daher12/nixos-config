{
  pkgs,
  config,
  mainUser,
  ...
}:

let
  # --- HOST CONFIGURATION ---
  # Hardware GIDs, pinned declaratively in hosts/nix-media/default.nix
  # (users.groups.{video,render}.gid) so allocation drift can't silently
  # break QSV (permission denied on /dev/dri/renderD128).
  renderGid = toString config.users.groups.render.gid;
  videoGid = toString config.users.groups.video.gid;

  # ID Mapping from Media Role
  uid = toString config.roles.media.nfsAnonUid;
  gid = toString config.roles.media.nfsAnonGid;

  # Fleet service ports (roles.media.ports — single source with monitoring.nix
  # scrape targets and caddy.nix proxy targets). Container-side ports in the
  # mappings below are image-fixed literals.
  portCfg = config.roles.media.ports;

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

  # Units on the shared docker network (was spelled out twice each in the
  # network unit's before/requiredBy).
  consumers = [
    "docker-jellyfin.service"
    "docker-audiobookshelf.service"
  ];

  storagePath = "/mnt/storage";
  dockerPath = "/home/${mainUser}/docker";
  jellyfinCachePath = "/var/cache/jellyfin";
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
      # live-restore: containers survive daemon restarts/rebuilds.
      # No json-file log-opts on purpose: NixOS defaults log-driver to
      # "journald", so container stdout is already capped by the host's
      # journald config in default.nix (SystemMaxUse=500M etc.) — and
      # max-size/max-file are json-file-only opts that CRASH dockerd at
      # start ("unknown log opt for journald driver"; caught by the
      # nix-media-pipeline VM test 2026-10-31).
      daemon.settings = {
        "metrics-addr" = "127.0.0.1:${toString portCfg.dockerMetrics}";
        "live-restore" = true;
      };
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
            # persists in /config/data/plugins ("Intro Skipper" 12.0.4.0)
            # and loads without the mod. Jellyfin runs :latest with the
            # weekly auto-update (see images.jellyfin) — when it lands
            # 12.1+, update the plugin via its repository in the dashboard.
            PGID = gid;
            PUID = uid;
            TZ = tz;
            LIBVA_DRIVER_NAME = "iHD";
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
          # 0.0.0.0 is deliberate: two LAN devices (without tailscale) call
          # Jellyfin directly on :8096. Docker's DNAT never traverses the
          # nftables INPUT chain, so this one port is LAN-open by design —
          # everything else on this host stays tailnet-only.
          ports = [ "${toString portCfg.jellyfin}:8096" ];
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
          ports = [ "127.0.0.1:${toString portCfg.audiobookshelf}:80" ];
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
          ports = [ "127.0.0.1:${toString portCfg.cadvisor}:8080" ];
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
        before = consumers;
        requiredBy = consumers;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
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

      # Both data disks are nofail: without this gate a failed/late mount
      # lets dockerd auto-create the bind sources as empty dirs on the root
      # FS and the containers boot with empty libraries.
      "docker-jellyfin".unitConfig.RequiresMountsFor = [ "/mnt/storage" ];
      "docker-audiobookshelf".unitConfig.RequiresMountsFor = [ "/mnt/storage" ];

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
        description = "Pull latest Docker images and restart changed containers";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
        };
        path = [
          pkgs.docker
          pkgs.systemd
        ];
        script = ''
          set -eu
          # Digest-compare: restart a container only when its image actually
          # changed (the weekly pull otherwise bounced all three every Sunday
          # 03:00 even with no new digest). A jellyfin restart is further
          # skipped while ffmpeg is mid-transcode — the weekly timer retries
          # next Sunday.
          refresh() {
            local image="$1" unit="$2"
            local old new
            old=$(docker image inspect -f '{{.Id}}' "$image" 2>/dev/null || echo none)
            docker pull "$image"
            new=$(docker image inspect -f '{{.Id}}' "$image")
            if [ "$old" = "$new" ]; then
              echo "no change: $unit"
              return 0
            fi
            if [ "$unit" = "docker-jellyfin.service" ] && docker top jellyfin 2>/dev/null | grep -q ffmpeg; then
              echo "image changed but jellyfin is transcoding - skipping restart, retried next run: $unit"
              return 0
            fi
            systemctl restart "$unit"
            echo "restarted: $unit"
          }
          refresh ${images.jellyfin} docker-jellyfin.service
          refresh ${images.audiobookshelf} docker-audiobookshelf.service
          refresh ${images.cadvisor} docker-cadvisor.service
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
