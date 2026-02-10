{
  pkgs,
  lib,
  mainUser,
  ...
}:

let
  lanIf = "enp1s0";
  sshPort = 26;
  nfsPort = 2049;
  tailscaleCidr = "100.64.0.0/10";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/intel-gpu.nix
    ../../modules/roles/media.nix

    ./docker.nix
    ./monitoring.nix
    ./caddy.nix
    ./ntfy.nix
    ./maintenance.nix
  ];

  roles.media = {
    enable = true;
    dockerUid = 1001;
  };

  core.users.defaultShell = "zsh";
  core.sysctl.optimizeForServer = true;
  system.stateVersion = "24.05";

  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };

    kernelParams = [ "transparent_hugepage=madvise" ];
    kernel.sysctl."vm.dirty_writeback_centisecs" = 200;
    tmp.cleanOnBoot = true; 
  };

  # Features enabled via standardized options
  features.sops.enable = true;
  features.vpn.tailscale = {
    enable = true;
    trustInterface = true;
    routingFeatures = "server";
  };

  hardware.intel-gpu = {
    enable = true;
    enableOpenCL = true;
    enableVpl = true;
    enableGuc = true;
  };

  environment.systemPackages = with pkgs; [
    mergerfs xfsprogs nvme-cli smartmontools ethtool mosh wget aria2 trash-cli unrar unzip ox btop fastfetchMinimal
  ];

  networking = {
    networkmanager.enable = false;
    useNetworkd = true;
    interfaces.${lanIf}.useDHCP = lib.mkForce false;
    firewall.allowedTCPPorts = [ nfsPort ];
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
    uid = 1001;
    extraGroups = [ "docker" ];
  };

  users.groups.${mainUser}.gid = 982;

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
      ports = [ sshPort ];
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        UseDns = false;
      };
    };
    nfs.server = {
      enable = true;
      exports = ''
        /mnt/storage ${tailscaleCidr}(rw,async,crossmnt,fsid=0,no_subtree_check,no_root_squash,all_squash,anonuid=1001,anongid=982)
      '';
    };
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    thermald.enable = true;
    pipewire.enable = false;
    pulseaudio.enable = false;
  };
  security.rtkit.enable = false;
}
