{
  config,
  pkgs,
  lib,
  mainUser,
  ...
}:
{
  imports = [
    ./disks.nix
  ];

  # --- Identity ---
  # Pinned: install.sh hardcodes USER_UID=1000/USER_GID=1000 for chown.
  # Auto-assignment is non-deterministic across module composition changes.
  #users.users.${mainUser}.uid = 1000;
  #users.groups.${mainUser}.gid = 1000;

  # Root password managed via SOPS (see modules/core/users.nix).
  # hashedPasswordFile bind removed: impermanence bind-mount timing is not
  # guaranteed before 'users' activation; neededForUsers = true is the
  # correct ordering contract.

 users.users.dk.hashedPassword = lib.mkForce "$y$j9T$TXEIF4hc2wEPlZF.cI5Zl0$LqzAXinbsvA9MoaTbXJ1eBNxmXChpin9pbbSP3FKiCD";


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
      tmpfs = {
        enable = true;
        size = "80%";
      };
    };
    users = {
      description = "David";
      defaultShell = "fish";
    };
  };

  networking.hosts = {
    # Static entry: MagicDNS unreliable in our environment for NFS mounts
    # (observed resolution failures). Update if nix-media is re-enrolled:
    #   tailscale status | grep nix-media
    "100.123.189.29" = [ "nix-media" ];
  };

  # --- Features ---
  features = {
    impermanence = {
      enable = true;
      device = "/dev/mapper/cryptroot";
    };
    secureboot.enable = false;

    nas.enable = true;
    desktop-gnome.autoLogin = true;
    sops = {
      enable = true;
      method = "age";
    };
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
    systemPackages = with pkgs; [
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
        # Kept deliberately: if sops.age.keyFile is ever reverted to the
        # sops-nix default (/var/lib/sops-nix/key.txt), this bind ensures
        # the key survives root wipes.
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
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          parentDirectory.mode = "0755";
        }
        "/etc/ssh/ssh_host_ed25519_key.pub"
        {
          file = "/etc/ssh/ssh_host_rsa_key";
          parentDirectory.mode = "0755";
        }
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };

    persistence."/persist" = {
      hideMounts = true;
      allowTrash = true;
      users.dk = {
        directories = [
          "Documents"
          "Downloads"
        ];
      };
    };
  };

  fileSystems = {
    "/persist".neededForBoot = true;
    "/nix".neededForBoot = true;
  };

  programs.fuse.userAllowOther = true;
}
