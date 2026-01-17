{ config, pkgs, lib, ... }:

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
  boot.loader.systemd-boot = { enable = true; configurationLimit = 10; };
  boot.kernelParams = [ "transparent_hugepage=madvise" ];

  # --- Hardware ---
  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true; 
    enableVpl = true;    
    enableGuc = true;
  };

  # --- Networking & Security ---
  services.openssh = {
    enable = true;
    ports = [ 26 ];
    openFirewall = true; # Automatically opens TCP 26
  };
  
  # --- NFS Server (Strict v4 Only) ---
  services.rpcbind.enable = false; # Disable port 111 (Force v4)
  networking.firewall.allowedTCPPorts = [ 2049 ]; # Open only NFSv4

  services.nfs.server = {
    enable = true;
    # Disable v3/UDP listeners
    extraNfsdConfig = ''
      vers3=n
      udp=n
    '';
    exports = ''
      /mnt/storage 100.64.0.0/10(rw,async,crossmnt,fsid=0,no_subtree_check,all_squash,anonuid=1000,anongid=100)
    '';
  };

  # --- Auto Upgrade ---
  # GitOps Mode: Updates whenever the remote repo 'main' branch changes
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    allowReboot = false;
    flake = "github:daher12/nixos-config#nix-media"; 
    randomizedDelaySec = "45min";
  };

  # --- Services ---
  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };
  
  features.sops.enable = true;
  services.fstrim = { enable = true; interval = "weekly"; };
  services.thermald.enable = true;
  users.users.dk.extraGroups = [ "docker" ];
}
