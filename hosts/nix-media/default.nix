{
  pkgs,
  lib,
  mainUser,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix

    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
    ../../modules/hardware/intel-gpu.nix
  ];

  # ---------------------------------------------------------------------------
  # Boot & Kernel Tuning
  # ---------------------------------------------------------------------------
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [
      "transparent_hugepage=madvise"
    ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_background_bytes" = 134217728;
      "vm.dirty_bytes" = 536870912;
      "vm.dirty_writeback_centisecs" = lib.mkForce 200;
      "fs.inotify.max_user_watches" = lib.mkForce 1048576;
      "fs.inotify.max_user_instances" = 1024;
      "net.core.somaxconn" = 4096;
      "net.ipv4.ip_local_port_range" = "10240 65535";
    };
  };

  # ---------------------------------------------------------------------------
  # Hardware & Graphics
  # ---------------------------------------------------------------------------
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    xfsprogs
    wget
    mosh
    ethtool
    nvme-cli
    smartmontools
    trash-cli
    unrar
    unzip
    ox
    btop
    fastfetchMinimal
  ];

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking = {
    interfaces.enp1s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [ 2049 ];
  };

  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  # ---------------------------------------------------------------------------
  # Shell & User Environment
  # ---------------------------------------------------------------------------
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      histSize = 10000;
      ohMyZsh = {
        enable = true;
        theme = "agnoster";
      };
    };
    zoxide.enable = true;
    adb.enable = lib.mkForce false;
  };

  users.users.${mainUser} = {
    extraGroups = [ "docker" ];
    shell = pkgs.zsh;
  };

  # ---------------------------------------------------------------------------
  # Services
  # ---------------------------------------------------------------------------
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

    openssh = {
      enable = true;
      ports = [ 26 ];
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        UseDns = false;
      };
    };

    rpcbind.enable = lib.mkForce false;
    nfs = {
      server = {
        enable = true;
        exports = ''
          /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash)
        '';
      };
      settings.nfsd = {
        vers3 = "n";
        udp = "n";
      };
    };

    fstrim = {
      enable = true;
      interval = "weekly";
    };
    thermald.enable = true;

    pipewire.enable = lib.mkForce false;
    pulseaudio.enable = false;
    libinput.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;
    flatpak.enable = false;
    fwupd.enable = lib.mkForce false;
  };

  # ---------------------------------------------------------------------------
  # System Maintenance
  # ---------------------------------------------------------------------------
  system = {
    stateVersion = "24.05";
    autoUpgrade = {
      enable = true;
      dates = "04:00";
      operation = "boot";  # Stage new generation, don't auto-switch
      flake = "github:daher12/nixos-config#nix-media";
      randomizedDelaySec = "45min";
    };
  };

  features.sops.enable = true;
  security.rtkit.enable = lib.mkForce false;

  # ---------------------------------------------------------------------------
  # Weekly Reboot with Validation
  # ---------------------------------------------------------------------------
  systemd.services.weekly-maintenance-reboot = {
    description = "Weekly reboot into latest NixOS generation";
    serviceConfig.Type = "oneshot";
    
    script = ''
      set -e
      
      # 1. Abort if media is actively streaming
      ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8096/Sessions \
        | ${pkgs.jq}/bin/jq -e '. | length == 0' \
        || { echo "Active Jellyfin sessions, aborting"; exit 0; }
      
      # 2. Check if new generation exists
      CURRENT=$(readlink /run/current-system)
      NEXT=$(readlink /nix/var/nix/profiles/system)
      
      if [ "$CURRENT" = "$NEXT" ]; then
        echo "No new generation, skipping reboot"
        exit 0
      fi
      
      # 3. Dry-activate new generation (catches broken services)
      $NEXT/bin/switch-to-configuration test 2>&1 | tee /var/log/pre-reboot-test.log
      
      # 4. Schedule reboot
      echo "Validation passed, rebooting in 60s..."
      shutdown -r +1 "Applying weekly NixOS updates"
    '';
  };

  systemd.timers.weekly-maintenance-reboot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:30";
      Persistent = true;
    };
  };
}
