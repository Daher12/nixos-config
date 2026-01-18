{ config, lib, pkgs, ... }:

let
  user = "dk";
  
  # --- HOST CONFIGURATION: UPDATE THESE GIDs ---
  # Run 'getent group render | cut -d: -f3' on your host to verify.
  # These are critical for Jellyfin hardware transcoding.
  # The build will FAIL if renderGid is left as "REPLACE_ME".
  renderGid = "REPLACE_ME";  # e.g. "303" or "109"
  videoGid = "REPLACE_ME";   # e.g. "44" (Optional fallback)
  # ---------------------------------------------

  dockerNetwork = {
    name = "jellyfin";
    subnet = "172.18.0.0/16";
  };
  
  storagePath = "/mnt/storage";
  dockerPath = "/home/${user}/docker";
  jellyfinCachePath = "/var/cache/jellyfin";
in
{
  # [FAIL-SAFE] Assertions must be top-level module attributes
  # Strictly enforces that the render group is set.
  assertions = [
    {
      assertion = renderGid != "REPLACE_ME";
      message = ''
        [Docker Config Error] You must replace 'renderGid' in hosts/nix-media/docker.nix.
        Run 'getent group render' on the server to find the numeric ID (e.g., 109 or 303).
      '';
    }
  ];

  # --- Virtualisation ---
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        flags = [ "--all" "--force" ];
      };
      daemon.settings = {
        "metrics-addr" = "127.0.0.1:9323";
      };
    };

    oci-containers = {
      backend = "docker";
      
      containers = {
        # 1. Jellyfin (Media Server)
        jellyfin = {
          autoStart = true;
          image = "lscr.io/linuxserver/jellyfin:latest"; 
          environment = {
            DOCKER_MODS = "ghcr.io/intro-skipper/intro-skipper-docker-mod";
            PGID = "1000";
            PUID = "1000";
            TZ = "Europe/Berlin";
            LIBVA_DRIVER_NAME = "iHD";
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
            
            # [SECURE PARITY] GPU Access via Numeric GID
            "--group-add=${renderGid}" 
            
            # [RESILIENCE] Restart Policy
            "--restart=unless-stopped"

            "--cpus=3.5"
            "--shm-size=256m"
            "--pids-limit=1000"

            # Healthcheck
            # Note: Requires 'curl' inside the container image.
            "--health-cmd=curl -fsS http://localhost:8096/health || exit 1"
            "--health-interval=60s"
            "--health-retries=4"
            "--health-timeout=10s"
          ] 
          # [CORRECTED] Conditionally add video group only if configured
          ++ lib.optional (videoGid != "REPLACE_ME") "--group-add=${videoGid}";
        };

        # 2. Audiobookshelf
        audiobookshelf = {
          autoStart = true;
          image = "ghcr.io/advplyr/audiobookshelf:latest";
          environment = {
            AUDIOBOOKSHELF_UID = "1000";
            AUDIOBOOKSHELF_GID = "1000";
            TZ = "Europe/Berlin";
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
            "--restart=unless-stopped"
            "--memory=512m"
            "--cpus=0.5"
            "--pids-limit=100"
            
            # Healthcheck
            "--health-cmd=curl -fsS http://localhost/ping || exit 1"
            "--health-interval=60s"
            "--health-retries=3"
          ];
        };

        # 3. cAdvisor (Monitoring)
        cadvisor = {
          autoStart = true;
          image = "gcr.io/cadvisor/cadvisor:latest";
          volumes = [
            "/:/rootfs:ro"
            "/var/run:/var/run:ro"
            "/sys:/sys:ro"
            "/var/lib/docker/:/var/lib/docker:ro"
            "/dev/disk/:/dev/disk:ro"
          ];
          ports = [ "127.0.0.1:8080:8080" ];
          extraOptions = [
            "--restart=unless-stopped"
            "--device=/dev/kmsg"
            "--memory=256m"
            "--cpus=0.25"
            "--pids-limit=75"
          ];
        };
      };
    };
  };

  # Jellyfin Cache on TMPFS
  fileSystems."${jellyfinCachePath}" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2G" "mode=0755" "uid=1000" "gid=1000" "noatime" "nosuid" "nodev" ];
  };

  # --- Systemd Grouping ---
  systemd = {
    services = {
      # Ensure Network Exists
      "docker-network-jellyfin" = {
        description = "Ensure Docker network '${dockerNetwork.name}' exists";
        after = [ "docker.service" "docker.socket" ];
        requires = [ "docker.service" ];
        before = [ "docker-jellyfin.service" "docker-audiobookshelf.service" ];
        requiredBy = [ "docker-jellyfin.service" "docker-audiobookshelf.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        path = [ pkgs.docker ];
        script = ''
          NETWORK="${dockerNetwork.name}"
          SUBNET="${dockerNetwork.subnet}"
          
          if docker network inspect "$NETWORK" >/dev/null 2>&1; then
            EXISTING=$(docker network inspect "$NETWORK" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
            if [ "$EXISTING" != "$SUBNET" ]; then
              echo "WARNING: Network '$NETWORK' exists with different subnet ($EXISTING vs $SUBNET)"
            else
              echo "Network '$NETWORK' exists with correct subnet."
            fi
          else
            docker network create "$NETWORK" --subnet="$SUBNET"
          fi
        '';
      };

      # Resource Prioritization
      "docker-jellyfin" = {
        serviceConfig = {
          IOWeight = 8000;
          CPUWeight = 1000;
          OOMScoreAdjust = -500;
        };
      };

      "docker-audiobookshelf" = {
        serviceConfig = {
          IOWeight = 100;
          CPUWeight = 100;
          OOMScoreAdjust = 500;
        };
      };

      "docker-cadvisor" = {
        serviceConfig = {
          CPUWeight = 50;
          OOMScoreAdjust = 700;
        };
      };

      # Image Refresh Script
      "docker-image-refresh" = {
        description = "Pull latest Docker images and restart containers";
        serviceConfig = { Type = "oneshot"; User = "root"; };
        path = [ pkgs.docker pkgs.systemd ];
        script = ''
          set -e
          echo "Refreshing Docker images..."
          docker pull lscr.io/linuxserver/jellyfin:latest
          docker pull ghcr.io/advplyr/audiobookshelf:latest
          docker pull gcr.io/cadvisor/cadvisor:latest
          
          echo "Restarting services..."
          systemctl restart docker-jellyfin.service docker-audiobookshelf.service docker-cadvisor.service
          
          echo "Pruning old images..."
          docker image prune -f
        '';
      };
    };

    timers = {
      "docker-image-refresh" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 03:00";
          Persistent = true;
          RandomizedDelaySec = "5min";
        };
      };
    };
  };
}
