{
  pkgs,
  lib,
  config,
  mainUser,
  ...
}:

let
  lanIf = "enp1s0";
  sshPort = 26;
  nfsPort = 2049;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/media.nix

    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix
  ];

  # --- Core Configuration ---
  core = {
    boot.tmpfs = {
      enable = true;
      size = "4G";
    };

    nix.gc = {
      automatic = true;
      dates = "Sun 04:00";
      flags = "--delete-older-than 60d";
    };

    users.defaultShell = "zsh";
    sysctl.optimizeForServer = true;
  };

  roles.media = {
    enable = true;
    nfsAnonUid = 1001;
    nfsAnonGid = 982;
  };

  system.stateVersion = "24.05";

  core.openssh.enable = true;

  boot = {
    loader.systemd-boot = {
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];
    kernel.sysctl."vm.dirty_writeback_centisecs" = 200;
  };

  # LiteLLM gateway config (model list + provider keys + master key) for
  # features.litellm below. Dedicated side file: nix-media.yaml itself is
  # still encrypted to the retired admin key (see .sops.yaml), so new
  # nix-media secrets go into separate files until the re-encryption.
  # Root:root 0400 by sops default — the DynamicUser service reads it via
  # systemd LoadCredential.
  sops.secrets."litellm_config" = {
    sopsFile = ../../secrets/hosts/nix-media-litellm.yaml;
    restartUnits = [ "litellm.service" ];
  };

  # Features enabled via standardized options
  features = {
    sops.enable = true;

    vpn.tailscale = {
      enable = true;
      trustInterface = true;
      routingFeatures = "server";
    };

    # OpenAI-compatible gateway for Obsidian Copilot on the tailnet devices
    # (yoga + iPhone): they call http://100.123.189.29:4001/v1 with the
    # master key from the litellm_config secret. 0.0.0.0 is safe here —
    # tailscale0 is the only firewall-trusted interface (see below), LAN
    # stays closed. Runs on the always-on server so AI survives yoga
    # being asleep/off.
    litellm = {
      enable = true;
      listenAddress = "0.0.0.0";
      configFile = config.sops.secrets."litellm_config".path;
    };

    mnamer = {
      enable = true;

      # paths and formats keep the module defaults (/mnt/storage/{downloads,
      # movies, shows} and the "{name} ({year})" naming scheme).
      ignore = [
        ".*sample.*"
        "^RARBG.*"
        ".*\\.part[0-9]+.*"
        ".*\\btrailer\\b.*"
        ".*\\bnfo\\b.*"
      ];

      extraSettings = {
        hits = 8;
      };

      extraCliArgs = [ "--no-style" ];
    };
  };

  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true; # Critical for HDR→SDR tone mapping
    enableVpl = true;
    enableGuc = true;
  };

  # ncurses 6.6 doesn't ship xterm-kitty, so an ssh session from kitty (or a
  # stale ghostty) hits "can't find terminal definition for xterm-kitty" via
  # /etc/set-environment. This pulls the kitty/ghostty/tmux terminfo outputs.
  environment.enableAllTerminfo = true;

  environment.systemPackages = [
    pkgs.mergerfs
    pkgs.xfsprogs
    pkgs.nvme-cli
    pkgs.smartmontools
    pkgs.ethtool
    pkgs.mosh
    pkgs.wget
    pkgs.aria2
    pkgs.trash-cli
    pkgs.unrar
    pkgs.unzip
    pkgs.ox
    pkgs.btop
    pkgs.fastfetch.minimal
  ];

  networking = {
    networkmanager.enable = false;
    useNetworkd = true;
    interfaces.${lanIf}.useDHCP = lib.mkForce false;

    firewall = {
      allowedTCPPorts = [ ];
      # Close global access; roles.media handles exports, we allow traffic here.
      # tailscale0 is trusted wholesale via features.vpn.tailscale anyway —
      # listing the ports documents intent and survives trustInterface=false.
      interfaces."tailscale0".allowedTCPPorts = [
        nfsPort
        config.features.litellm.port
      ];
    };
  };

  systemd.network = {
    links."10-${lanIf}" = {
      matchConfig.Name = lanIf;
      linkConfig.WakeOnLan = "magic";
    };
    networks."10-lan" = {
      matchConfig.Name = lanIf;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
    };
    wait-online = {
      enable = true;
      timeout = 30;
      extraArgs = [ "--interface=${lanIf}:routable" ];
    };
  };

  users.users.${mainUser} = {
    uid = config.roles.media.nfsAnonUid;
    extraGroups = [ "docker" ];
  };

  users.groups.${mainUser}.gid = config.roles.media.nfsAnonGid;

  # HDD streaming fix — hangs in read-ahead, not scheduler.
  # Root cause: default read_ahead_kb=128 forces tiny USB transfers, starving
  # the video buffer mid-playback.  4MB gives ~800ms of 4K video per read.
  # Scheduler=none because USB bridge chip does its own queuing; deadline
  # on top just adds latency bubbles (confirmed via iostat — 136KB dirty,
  # no writeback contention, mq-deadline was fine but unnecessary).
  # Remove these once mergerfs gets read-ahead passthrough or kernel default
  # is bumped for rotational USB:
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*", ATTR{queue/rotational}=="1", ATTR{bdi/read_ahead_kb}="4096"
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="none"
  '';

  services = {
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=500M
      SystemMaxFileSize=50M
      MaxRetentionSec=2592000
      RateLimitInterval=30s
      RateLimitBurst=1000
    '';

    logrotate.enable = true;
    # sshd hardening (PasswordAuthentication/PermitRootLogin/UseDns) via core.openssh
    openssh = {
      ports = [ sshPort ];
      openFirewall = true;
    };
    fstrim = {
      enable = true;
      interval = "weekly";
    };

    # thermald comes from hardware.intel-gpu (mkDefault)
    # Server host — no audio stack needed. Overrides mkDefault in modules/core/audio.nix.
    pipewire.enable = false;
    pulseaudio.enable = false;
  };

  security.rtkit.enable = false;
}
