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
  sops.secrets.root_password_hash = {
    neededForUsers = true;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;

  # ADB group for android-tools (not in core/users.nix since only yoga needs it)
  users.users.${mainUser}.extraGroups = [ "adbusers" ];

  # --- Hardware & Boot ---
  boot = {
    loader.timeout = 0;
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
      ];

      # Prevent amdgpu from loading in initrd so simpledrm survives for Plymouth.
      # lib.mkForce beats amd-gpu.nix and nixos-hardware yoga module.
      # Preserves btrfs/dm_mod (LUKS) and kvm/kvm-amd (amd-kvm.nix).
      kernelModules = lib.mkForce [
        "btrfs"
        "dm_mod"
        "kvm"
        "kvm-amd"
      ];

      # Block udev PCI modalias auto-load of amdgpu in initrd.
      # Without this, udev loads amdgpu before systemd-modules-load runs,
      # removing simpledrm before Plymouth can attach to it.
      systemd.contents."/etc/modprobe.d/no-amdgpu.conf".text = ''
        blacklist amdgpu
      '';
    };
    kernelModules = [ "ryzen_smu" ];
    extraModulePackages = [ config.boot.kernelPackages."ryzen-smu" ];
    blacklistedKernelModules = [ "ipheth" ];
  };

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    isPhysical = true;
    amd-gpu.enable = true;
    amd-kvm.enable = true;
    ryzen-tdp = {
      enable = true;
      ac = {
        stapm = 50;
        fast = 60;
        slow = 50;
        temp = 85;
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
        size = "2G";
      };
    };
    users = {
      description = "David";
      defaultShell = "fish";
    };
    networking.enablePowersave = false; # disable wifi powersave (NM wifi.powersave=2) — fixes iwlwifi AX210 roaming/AP handoff (was powersave=3)
  };

  # --- Features ---
  features = {
    impermanence = {
      enable = true;
      device = "/dev/mapper/cryptroot";
    };

    secureboot.enable = true;
    nas = {
      enable = true;
      serverIp = "100.123.189.29"; # Tailscale IP of nix-media
    };

    desktop-gnome.autoLogin = true;

    onlyoffice = {
      enable = true;
      installCompatibilityFonts = false;
      cursorSize = 64;
      setGlobalCursorSize = true;
    };

    # TEMPORARY: disabled until new admin key is generated and secrets re-encrypted
    sops = {
      enable = true;
      method = "age";
    };

    zram = {
      enable = true;
      memoryPercent = 50;
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
      # Uncomment if Plymouth LUKS prompt shows 8s delay or text-mode fallback.
      # Blocks amdgpu module_init in initrd so simpledrm survives for Plymouth.
      # Not needed if LUKS prompt appears promptly via simpledrm.
      # "initcall_blacklist=amdgpu_init"
    ];

    virtualization = {
      enable = true;
      windows11 = {
        enable = true;
        name = "windows11";
        ip = "192.168.122.139";
        mac = "52:54:00:03:b9:49";
      };
    };

    power-tlp.settings = {
      TLP_DEFAULT_MODE = "BAT";
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_SCALING_MIN_FREQ_ON_AC = 403730;
      CPU_SCALING_MIN_FREQ_ON_BAT = 403730;
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PCIE_ASPM_ON_BAT = "powersupersave";
      WIFI_PWR_ON_AC = "off"; # explicit — default is off, ensures no TLP wifi powersave on AC (you're currently on AC)
      WIFI_PWR_ON_BAT = "off"; # disable TLP wifi powersave on BAT — fixes roaming/AP handoff when on battery (default would be "on")
    };
  };

  # --- Services & Systemd ---
  systemd = {
    tmpfiles.rules = [
      "d /persist 0755 root root - -"
      "d /persist/home/ 0711 ${mainUser} ${mainUser} - -"
      "d /persist/home/${mainUser} 0700 ${mainUser} ${mainUser} - -"
      "d /persist/system/var/lib/local-passwords 0700 root root - -"
    ];
  };

  services = {
    journald.extraConfig = "SystemMaxUse=200M";
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  # --- Environment & Filesystems ---
  environment = {
    systemPackages = [
      pkgs.android-tools
      pkgs.libva-utils
      pkgs.vulkan-tools
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
        "/etc/brave/policies/managed/bloat.json"
      ];
    };

    persistence."/persist" = {
      hideMounts = true;
      allowTrash = true;
      users.${mainUser} = {
        directories = [
          "Schreibtisch"
          "Dokumente"
          "Downloads"
          "Musik"
          "Bilder"
          "Öffentlich"
          "Vorlagen"
          "Videos"
          "nixos-config"
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
