{
  pkgs,
  lib,
  mainUser,
  ...
}:

{
  imports = [
    # Hardware & Architecture
    ./hardware-configuration.nix
    ../../modules/hardware/intel-gpu.nix

    # Service Modules
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix # NEW: Encapsulates auto-upgrade & reboot logic

    # Global Features
    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
  ];

  # ---------------------------------------------------------------------------
  # Core Configuration
  # ---------------------------------------------------------------------------
  core.users.defaultShell = "zsh";
  core.sysctl.optimizeForServer = true;

  system.stateVersion = "24.05";

  # ---------------------------------------------------------------------------
  # Boot & Kernel Tuning
  # ---------------------------------------------------------------------------
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];

    # Host-specific sysctl overrides (additive to core.sysctl.optimizeForServer)
    kernel.sysctl = {
      "vm.dirty_writeback_centisecs" = lib.mkForce 200;
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
  # Users
  # ---------------------------------------------------------------------------
  users.users.${mainUser}.extraGroups = [ "docker" ];

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

    # Headless Optimizations (stripping unused desktop/audio stacks)
    pipewire.enable = false;
    pulseaudio.enable = false;
    libinput.enable = false;
    udisks2.enable = false;
    flatpak.enable = false;
    fwupd.enable = false;
  };

  features.sops.enable = true;
  security.rtkit.enable = false;
}
