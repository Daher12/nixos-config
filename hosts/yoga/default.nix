{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disks.nix
  ];

  # --- Hardware & Boot ---
  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [ "ryzen_smu" ];
    extraModulePackages = [ config.boot.kernelPackages."ryzen-smu" ];
  };

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    isPhysical = true;
    amd-gpu.enable = true;
    amd-kvm.enable = true;
    ryzen-tdp = {
      enable = true;
      ac = {
        stapm = 54;
        fast = 60;
        slow = 54;
        temp = 95;
      };
      battery = {
        stapm = 18;
        fast = 25;
        slow = 18;
        temp = 75;
      };
    };
  };

  # --- System Core ---
  system.stateVersion = "25.11";
  core = {
    boot = {
      plymouth.theme = "bgrt";
      tmpfs = { enable = true; size = "80%"; };
    };
    users = {
      description = "David";
      defaultShell = "fish";
    };
  };

  networking.hosts = {
    "100.123.189.29" = [ "nix-media" ];
  };

  # --- Features ---
  features = {
    impermanence = {
      enable = true;
      device = "/dev/mapper/cryptroot";
    };
    secureboot.enable = true;

    nas.enable = true;
    desktop-gnome.autoLogin = true;
    sops.enable = true;
    filesystem = {
      type = "btrfs";
      btrfs = {
        autoScrub = true;
        scrubFilesystems = [ "/persist" ];
        autoBalance = true;
      };
    };

    kernel.extraParams = [
      "zswap.enabled=0"
      "amd_pstate=active"
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.dcdebugmask=0x10"
    ];
    virtualization = {
      enable = true;
      windows11.enable = true;
    };
    power-tlp.settings = {
      TLP_DEFAULT_MODE = "BAT";
      TLP_PERSISTENT_DEFAULT = 1;
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_SCALING_MIN_FREQ_ON_AC = 403730;
      CPU_SCALING_MIN_FREQ_ON_BAT = 403730;
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # --- Services & Systemd ---
  systemd = {
    services.nix-daemon.serviceConfig =
      let
        cores = config.nix.settings.cores or 0;
      in
      lib.mkIf (cores > 0) { CPUQuota = "${toString (cores * 100)}%"; };
    tmpfiles.rules = [
      "d /persist 0755 root root - -"
      "d /persist/home/dk 0700 dk dk - -"
    ];
  };

  services = {
    irqbalance.enable = true;
    journald.extraConfig = "SystemMaxUse=200M";
  };

  # --- Environment & Filesystems ---
  environment = {
    systemPackages = with pkgs;
    [
      libva-utils
      vulkan-tools
    ];
    persistence."/persist/system" = {
      hideMounts = true;
      directories = [
        "/etc/NetworkManager/system-connections"
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/iwd"
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/lib/tailscale"
        "/var/lib/sops-nix"
        "/var/lib/upower"
        "/var/lib/colord"
        "/var/db/sudo/lectured"
        "/var/lib/libvirt"
        "/var/lib/gdm"
        "/var/lib/AccountsService"
        "/var/lib/fwupd"
      ];
      files = [
        "/etc/machine-id"
        { file = "/etc/ssh/ssh_host_ed25519_key";
        parentDirectory.mode = "0755"; }
        "/etc/ssh/ssh_host_ed25519_key.pub"
        { file = "/etc/ssh/ssh_host_rsa_key";
        parentDirectory.mode = "0755"; }
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
  fileSystems = {
    "/persist".neededForBoot = true;
    "/nix".neededForBoot = true;
  };

  programs.fuse.userAllowOther = true;
}
