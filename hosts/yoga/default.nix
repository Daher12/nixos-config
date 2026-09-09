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
    ./yoga-s2h.nix
  ];

  # --- Identity ---
  sops.secrets.root_password_hash = {
    neededForUsers = true;
  };

  # MikroTik MCP (mikromcp): flip to false to disable the opencode MCP server
  # (keeps ~/.mikromcp data persisted either way).
  home-manager.users.${mainUser}.custom.mikrotikMcp.enable = false;

  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;

  # ADB group for android-tools (not in core/users.nix since only yoga needs it)
  users.users.${mainUser}.extraGroups = [ "adbusers" ];

  # --- Hardware & Boot ---
  boot = {
    loader.timeout = 0;
    # Resume device for hibernation: the LUKS device holding the swapfile
    # (/var/lib/swap/swapfile). Kernel param `resume` comes from this; the
    # btrfs-specific `resume_offset` is set in features.kernel.extraParams.
    resumeDevice = "/dev/mapper/cryptroot";
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
    # nixpkgs pins ryzen-smu at 2025-10-22, which predates the mainline x86
    # cpuid API split in kernel 7.2 (the declarations moved out of the old
    # include chain into asm/cpuid/api.h), so the module fails to build on
    # any 7.2-based kernel — zen tracks 7.2 now too. Pin upstream's own fix
    # (d298366, "Fix cpuid include on 7.2+ kernels", 2026-08-15); drop this
    # override once nixpkgs moves past it.
    extraModulePackages = [
      (config.boot.kernelPackages."ryzen-smu".overrideAttrs (_: {
        version = "0.1.7-unstable-2026-08-15";
        src = pkgs.fetchFromGitHub {
          owner = "amkillam";
          repo = "ryzen_smu";
          rev = "d2983668300dd2a598e5a7dc40e71ce0678cc270";
          hash = "sha256-OmEoycRO3hGkqueLa0i6AzmwMEbdkkPrwJkMyYxOTek=";
        };
      }))
    ];
    blacklistedKernelModules = [ "ipheth" ];
  };

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
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
    openssh.enable = true;
  };

  # --- WiFi (iwd) tuning ---
  # iwd is the backend (core.networking.backend = "iwd") and has no client-side
  # switch for 802.11r FT, so the AX210 roaming handoff failures can't be
  # disabled here — only worked around. RoamRetryInterval spaces out retries
  # after a failed FT handover.
  networking.wireless.iwd.settings = {
    General = {
      RoamRetryInterval = 120;
    };
  };

  # --- Features ---
  features = {
    impermanence = {
      enable = true;
      device = "/dev/mapper/cryptroot";
    };

    secureboot.enable = true;
    # serverIp uses the features.nas option default (Tailscale IP of nix-media)
    nas.enable = true;

    desktop-gnome.autoLogin = true;

    onlyoffice = {
      enable = true;
      installCompatibilityFonts = false;
      cursorSize = 64;
      setGlobalCursorSize = true;
    };

    sops = {
      enable = true;
      method = "age";
    };

    # memoryPercent is the *uncompressed* capacity cap (nixpkgs docs: "doesn't define
    # how much memory will be used"), so 100% of RAM costs only ~5-6 GiB actual RAM
    # at lz4's ~2.5-3x ratio. 50% filled up with no release valve -> lockups.
    zram = {
      enable = true;
      memoryPercent = 100;
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
      # Hibernation to the btrfs swapfile (/var/lib/swap/swapfile). The offset
      # is the swapfile's *device-physical* start (NOT filefrag's value):
      #   sudo btrfs inspect-internal map-swapfile -r /var/lib/swap/swapfile
      # Derived 2026-09-03. Valid as long as the swapfile's first extent stays
      # put — it is pinned by swapon from boot, and balance/scrub skip active
      # swapfile block groups. If hibernate ever boots normally instead of
      # resuming (stale offset = lost session, no corruption), re-derive it.
      "resume_offset=7697093"
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
    };
  };

  # --- Swap ---
  # Disk-backed overflow swap: only touched once zram (priority 10) is full.
  # NixOS creates it via `btrfs filesystem mkswapfile` (NOCOW-safe on this
  # compress-force=zstd root); lives on /persist so it survives root reset.
  # priority left null -> kernel assigns a negative one, below zram's 10.
  swapDevices = [
    {
      device = "/var/lib/swap/swapfile";
      size = 16 * 1024; # MiB
    }
  ];

  # --- Services & Systemd ---
  systemd = {
    # Go straight to s2idle: this firmware advertises S3 but rejects it
    # instantly ("PM: suspend entry (deep)" → exit in the same second, every
    # cycle; mem_sleep_default=deep comes from nixos-hardware). The "then
    # hibernate after 2h" half of suspend-then-hibernate is implemented by
    # the system-sleep hook below — systemd 260's built-in s2h silently
    # cancels itself on this machine (see REPO_OVERVIEW Known Gotchas).
    sleep.settings.Sleep = {
      # systemd 260's sleep.conf key for /sys/power/mem_sleep is
      # MemorySleepMode= — "SuspendMode=" is NOT a valid key and is silently
      # ignored (journal 2026-09-07: every suspend tried "deep" first, the
      # firmware rejected it in the same second, and systemd's own <5s
      # retry fell back to s2idle). With the right key, systemd-sleep
      # writes s2idle to mem_sleep directly and the dead deep attempt
      # disappears.
      MemorySleepMode = "s2idle";
      # Write the image, then power off via plain shutdown instead of the
      # firmware's ACPI-S4 platform path. This firmware's ACPI power
      # management is untrustworthy (broken S3, RTC wakealarm truncation
      # bug); the 2026-09-06 hibernate attempt died in exactly that
      # platform handoff. Resume from disk is identical either way.
      # (Verified applied: /sys/power/disk showed [shutdown] selected after
      # the 2026-09-07 04:00 hibernate.)
      HibernateMode = "shutdown";
    };
    tmpfiles.rules = [
      # Cap the hibernation image at 4G. This drives how deep the kernel's
      # pre-snapshot reclaim goes (the screen-dark wait before the image is
      # taken): 2G gave 3.6x free-page margin but produced 17-minute
      # reclaims on heavy sessions (2026-09-07 22:19). The old 5.9G kernel
      # default was only dangerous BEFORE the hook swapped zram out first
      # (zram kept swapped pages resident in RAM — the real cause of the
      # 2026-09-03/06 ENOMEM aborts); with swapoff in place 4G halves the
      # reclaim while keeping >1.5x margin. Check margins in the journal:
      # "Normal pages needed: X, available pages: Y".
      "w /sys/power/image_size - - - - 4294967296"
      "d /persist 0755 root root - -"
      "d /persist/home/ 0711 ${mainUser} ${mainUser} - -"
      "d /persist/home/${mainUser} 0700 ${mainUser} ${mainUser} - -"
      "d /persist/system/var/lib/local-passwords 0700 root root - -"
    ];
  };

  services = {
    # Lid policy is inherited from profiles/laptop.nix (suspend on battery,
    # ignore on AC/docked) — deliberately NOT "suspend-then-hibernate":
    # systemd 260's s2h never hibernates on this machine. Its RTC wakealarm
    # fires ~1s before the (microsecond-precision, truncated-to-seconds)
    # BOOTTIME timer deadline, so every timer wake is misclassified as a
    # manual wakeup and s2h exits silently; logind's 30s resume holdoff then
    # re-triggers the still-closed lid and the cycle restarts (observed
    # 2026-09-04/05: 2h loops all night, zero hibernations, ~30s awake per
    # cycle — also the extra battery drain). The "then hibernate after 2h"
    # half lives in the system-sleep hook below instead. Full analysis in
    # REPO_OVERVIEW Known Gotchas.

    journald.extraConfig = "SystemMaxUse=200M";
    # sshd hardening via core.openssh (PasswordAuthentication=no,
    # PermitRootLogin=no, UseDns=no).
  };

  # --- Environment & Filesystems ---
  environment = {
    systemPackages = [
      pkgs.android-tools
      pkgs.libva-utils
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
        {
          directory = "/var/lib/swap";
          mode = "0700";
        }
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
