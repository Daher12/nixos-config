{ lib, ... }:

{
  features = {
    intel-qsv.enable = lib.mkDefault true;
    media-server.enable = lib.mkDefault true;
    monitoring-stack = {
      enable = lib.mkDefault true;
      intelGpuMetrics = lib.mkDefault true;
      alertmanager.enable = lib.mkDefault true;
    };
    notifications = {
      enable = lib.mkDefault true;
      alertmanagerBridge = lib.mkDefault true;
      smartdNotifications = lib.mkDefault true;
      bootNotification = lib.mkDefault true;
    };
    filesystem.enableFstrim = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
    vpn.tailscale.enable = lib.mkDefault true;
  };

  core = {
    boot.silent = lib.mkDefault false;
    nix = {
      gc = {
        automatic = lib.mkDefault true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 8d";
      };
      optimise = {
        automatic = lib.mkDefault true;
      };
    };
  };

  # Nix store optimization timing (before auto-upgrade)
  nix.optimise.dates = lib.mkDefault [ "02:00" ];

  # Flake-based auto-upgrade (use self-reference)
  system.autoUpgrade = {
    enable = lib.mkDefault true;
    dates = lib.mkDefault "04:00";
    allowReboot = lib.mkDefault false;
    flake = lib.mkDefault "git+file:///home/dk/nixos-config#nix-media";
    flags = [
      "--update-input"
      "nixpkgs"
      "--commit-lock-file"
    ];
  };

  # Systemd optimizations
  systemd = {
    extraConfig = ''
      DefaultTimeoutStopSec=15s
      DefaultTimeoutStartSec=30s
    '';
    services.NetworkManager-wait-online.enable = lib.mkForce false;
  };

  # Headless server - disable desktop services
  services.xserver.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  services.flatpak.enable = lib.mkForce false;
  services.udisks2.enable = lib.mkForce false;
  documentation.enable = lib.mkForce false;

  # Server-specific services
  services.logrotate.enable = lib.mkDefault true;
  services.thermald.enable = lib.mkDefault true;
  services.irqbalance.enable = lib.mkDefault true;
}
