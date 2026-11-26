{
  pkgs,
  lib,
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
    # Silo A/B trial (2026-11). :latest rides the weekly refresh like the
    # others; upstream also tags per-build "build-N" if a release ever
    # needs pinning. The DB lives inside the image's /config — pin + dump
    # before any major PostgreSQL jump (see upstream docker docs).
    silo = "ghcr.io/silo-server/silo-server:latest";
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
  # Silo trial: RAM-backed transcode/download scratch mirroring jellyfin's
  # tmpfs, at 4G — both servers draw on the same RAM budget (spill is swap).
  # Drop to a disk-backed dir under dockerPath if memory pressure shows up.
  siloCachePath = "/var/cache/silo";
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

        # Silo — A/B trial against Jellyfin. Omnibus image (Silo + bundled
        # PostgreSQL + Redis under one s6 supervisor). The Jellyfin-compat
        # (8096) and Audiobookshelf-compat (13378) ports stay unpublished:
        # they collide with the real services, and Silo's own apps talk to
        # the web port. The image carries its own HEALTHCHECK (20-min
        # start-period absorbs DB migrations) — adding --health-cmd here
        # would silently replace it, so none is set.
        silo = {
          image = images.silo;
          environment = {
            PGID = gid;
            PUID = uid;
            TZ = tz;
            # Image default is off (transcode nodes don't want it); the
            # omnibus server compose pins it on — Watch Party needs Redis.
            ENABLE_REDIS = "true";
          };
          # SECRET_KEY (at-rest credential encryption for the bundled DB)
          # via sops env file, never inlined. Losing it forces an
          # empty-database restart; the key is backed up in the password
          # manager as well.
          environmentFiles = [ config.sops.secrets."silo_secret_key".path ];
          volumes = [
            "${dockerPath}/silo/config:/config"
            # Artwork cache OUTSIDE the writable layer: the unit recreates
            # the container on every image refresh/rebuild, which would
            # wipe a layer-resident cache and re-fetch GBs from TMDB.
            # Stays on the NVMe (small random reads) — the HDD pool is for
            # media, not the artwork cache.
            "${dockerPath}/silo/artwork:/var/lib/silo/artwork"
            "${siloCachePath}/transcode:/tmp/silo-transcode"
            "${siloCachePath}/download-artifacts:/tmp/silo-download-artifacts"
            "${dockerPath}/silo/catalog-seeds:/catalog-seeds:ro"
            "${storagePath}/movies:/mnt/media/movies:ro"
            "${storagePath}/shows:/mnt/media/shows:ro"
            "${storagePath}/kinder:/mnt/media/kinder:ro"
          ];
          # 0.0.0.0 deliberate, same rationale as Jellyfin: Silo's apps
          # switch to http://<LAN-IP>:8090 at home, and Docker's DNAT never
          # traverses the nftables INPUT chain. The HTTPS path is caddy's
          # :8443 listener (caddy.nix) — Silo does not support sub-path
          # proxying, so it cannot join the /<name>/ scheme.
          ports = [ "${toString portCfg.silo}:8080" ];
          extraOptions = [
            "--device=/dev/dri:/dev/dri"
            "--group-add=${renderGid}"
            "--group-add=${videoGid}"
            "--cpus=2.0"
            "--shm-size=2g"
            "--pids-limit=1500"
            # No --stop-timeout needed: the oci-containers unit has no
            # ExecStop — systemd SIGTERMs the attached docker run client,
            # sig-proxy forwards to s6, and the module's hardcoded
            # TimeoutStopSec=120 matches upstream stop_grace_period (2m).
            # On stop Silo fails readiness, finishes in-flight requests,
            # and PostgreSQL shuts down last.
          ];
        };

        cadvisor = {
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
            # Healthcheck gap closed (audit 2026-11-18): cadvisor is the
            # lynchpin of the ContainerDown alert (monitoring.nix) but was
            # the only container without a healthcheck. The image ships
            # busybox wget (live-proven: no curl, no /healthz FILE — the
            # HTTP endpoint is what returns "ok"), so probe that.
            "--health-cmd=wget -q -O- http://localhost:8080/healthz || exit 1"
            "--health-interval=60s"
            "--health-retries=3"
            "--health-timeout=10s"
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

  fileSystems."${siloCachePath}" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=4G" # trial budget — see the siloCachePath note above
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
    "d ${siloCachePath} 0755 ${uid} ${gid} - -"
    "d ${siloCachePath}/transcode 0755 ${uid} ${gid} - -"
    "d ${siloCachePath}/download-artifacts 0755 ${uid} ${gid} - -"
    # Self-healing ownership for the migrated artwork dir: if it's ever
    # lost, recreating it root-owned would leave silo (uid ${uid}) unable
    # to write its cache.
    "d ${dockerPath}/silo/artwork 0755 ${uid} ${gid} - -"
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

      # Resource limits only - cleanup handled by oci-containers.
      # startLimit* go TOP-LEVEL, not inside serviceConfig: they are [Unit]
      # keys, and systemd ignores them in [Service] ("Unknown lvalue").
      "docker-jellyfin" = {
        startLimitBurst = 10;
        startLimitIntervalSec = 300;
        serviceConfig = {
          # mkForce: the oci-containers module plain-sets on-failure, under
          # which a container that exits 0 stays down until the Sunday
          # refresh restarts it — wrong for long-running media servers.
          Restart = lib.mkForce "always";
          IOWeight = 8000;
          CPUWeight = 1000;
          OOMScoreAdjust = -500;
        };
      };

      # Both data disks are nofail: without this gate a failed/late mount
      # lets dockerd auto-create the bind sources as empty dirs on the root
      # FS and the containers boot with empty libraries.
      "docker-jellyfin".unitConfig.RequiresMountsFor = [ "/mnt/storage" ];
      "docker-audiobookshelf".unitConfig.RequiresMountsFor = [ "/mnt/storage" ];
      "docker-silo".unitConfig.RequiresMountsFor = [ "/mnt/storage" ];

      "docker-audiobookshelf" = {
        startLimitBurst = 10;
        startLimitIntervalSec = 300;
        serviceConfig = {
          # mkForce: see the docker-jellyfin note (module plain-sets on-failure).
          Restart = lib.mkForce "always";
          IOWeight = 100;
          CPUWeight = 100;
          OOMScoreAdjust = 500;
        };
      };

      "docker-silo" = {
        startLimitBurst = 10;
        startLimitIntervalSec = 300;
        serviceConfig = {
          # mkForce: see the docker-jellyfin note (module plain-sets on-failure).
          Restart = lib.mkForce "always";
          IOWeight = 100;
          CPUWeight = 100;
          OOMScoreAdjust = 500;
        };
      };

      "docker-cadvisor" = {
        startLimitBurst = 10;
        startLimitIntervalSec = 300;
        serviceConfig = {
          # mkForce: see the docker-jellyfin note (module plain-sets on-failure).
          Restart = lib.mkForce "always";
          CPUWeight = 50;
          OOMScoreAdjust = 700;
        };
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
          # Running-container compare: restart a container only when the image
          # it RUNS differs from the freshly pulled store image (the weekly
          # pull otherwise bounced every container every Sunday 03:00 even
          # with no new digest). Comparing store-vs-store was a trap: when a
          # jellyfin restart is skipped mid-transcode, the pull has already
          # updated the store, so every later run saw store==store ("no
          # change") and jellyfin stayed stranded on the old image until
          # upstream pushed ANOTHER digest — the "retried next run" promise
          # could never fire (fixed 2026-11-18). A jellyfin restart is still
          # skipped while ffmpeg is mid-transcode; the next run re-detects
          # running!=store and restarts it.
          refresh() {
            local image="$1" unit="$2" container="$3"
            local running new
            running=$(docker inspect -f '{{.Image}}' "$container" 2>/dev/null || echo none)
            docker pull "$image"
            new=$(docker image inspect -f '{{.Id}}' "$image")
            if [ "$running" = "$new" ]; then
              echo "up to date: $unit"
              return 0
            fi
            if [ "$unit" = "docker-jellyfin.service" ] && docker top jellyfin 2>/dev/null | grep -q ffmpeg; then
              echo "image changed but jellyfin is transcoding - skipping restart, retried next run: $unit"
              return 0
            fi
            systemctl restart "$unit"
            echo "restarted: $unit"
          }
          refresh ${images.jellyfin} docker-jellyfin.service jellyfin
          refresh ${images.audiobookshelf} docker-audiobookshelf.service audiobookshelf
          refresh ${images.silo} docker-silo.service silo
          refresh ${images.cadvisor} docker-cadvisor.service cadvisor
          # Dangling-image cleanup lives in the docker-prune timer
          # (autoPrune --all --force) — no prune here, it was double work.
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
