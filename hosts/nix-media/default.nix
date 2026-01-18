{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ../../modules/core
    ../../modules/features/sops.nix
    ../../modules/features/vpn.nix
    ../../modules/hardware/intel-gpu.nix
  ];

  system.stateVersion = "24.05";

  # --- Boot & Kernel ---
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.kernelParams = [ "transparent_hugepage=madvise" ];

  # --- Hardware ---
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  # --- Networking ---
  networking.firewall.allowedTCPPorts = [ 2049 ];

  # --- Services (Grouped for Statix) ---
  services = {
    # SSH
    openssh = {
      enable = true;
      ports = [ 26 ];
      openFirewall = true;
    };

    # NFS Server (Strict v4 Only)
    # FIX: The NFS module force-enables rpcbind by default.
    # We use mkForce to disable it for a strict v4-only (Port 2049) setup.
    rpcbind.enable = lib.mkForce false;

    nfs = {
      server = {
        enable = true;
        exports = ''
          /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,all_squash,anonuid=1000,anongid=100)
        '';
      };

      # Structured settings replace deprecated extraNfsdConfig
      settings.nfsd = {
        vers3 = "n";
        udp = "n";
      };
    };

    # Maintenance
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    thermald.enable = true;
  };

  # --- Auto Upgrade ---
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    allowReboot = false;
    flake = "github:daher12/nixos-config#nix-media";
    randomizedDelaySec = "45min";
  };

  # --- Features ---
  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  features.sops.enable = true;
  users.users.dk.extraGroups = [ "docker" ];
}
