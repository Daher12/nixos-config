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
  # Kernel packages left to default (NixOS 25.11 LTS) for maximum stability
  boot.kernelParams = [ "transparent_hugepage=madvise" ];

  # --- Hardware ---
  # Firmware and drivers are handled by the shared intel-gpu module
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
    openFirewall = true;
  };

  # --- NFS Server (Strict v4 Only) ---
  # FIX: The NFS module force-enables rpcbind by default.
  # We use mkForce to disable it for a strict v4-only (Port 2049) setup.
  services.rpcbind.enable = lib.mkForce false;

  # Only open the NFSv4 port
  networking.firewall.allowedTCPPorts = [ 2049 ];

  services.nfs.server = {
    enable = true;
    # Explicitly disable v3/UDP listeners in the NFS daemon config
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
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
  services.thermald.enable = true;
  users.users.dk.extraGroups = [ "docker" ];
}
