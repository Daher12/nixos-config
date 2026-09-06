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

  sops.secrets.orcarouter_api_key = {
    owner = config.users.users.${mainUser}.name;
    group = config.users.users.${mainUser}.group;
    mode = "0440";
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
      SuspendMode = "s2idle";
      # Write the image, then power off via plain shutdown instead of the
      # firmware's ACPI-S4 platform path. This firmware's ACPI power
      # management is untrustworthy (broken S3, RTC wakealarm truncation
      # bug); the 2026-09-06 hibernate attempt died in exactly that
      # platform handoff. Resume from disk is identical either way.
      HibernateMode = "shutdown";
    };
    tmpfiles.rules = [
      # Cap the hibernation image at 2G. The kernel default (~40% of RAM
      # ≈ 5.9G) left only ~105 MiB of free-page headroom on the aborted
      # 2026-09-06 attempt ("Normal pages needed: 1976561 + 1024, available
      # pages: 2004551") and ENOMEM-aborted outright on 2026-09-03; a
      # smaller image buys real margin at the cost of deeper pre-snapshot
      # reclaim. Tradeoff: aggressive reclaim is what mass-evicts TTM
      # buffers — the amdgpu LRU-corruption trigger (drm/amd #5470) — so
      # close memory-heavy apps before hibernating and reclaim won't have
      # to dig that deep.
      "w /sys/power/image_size - - - - 2147483648"
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

    # Self-implemented suspend-then-hibernate (the classic pre-systemd-252
    # pattern), because systemd 260's built-in s2h never hibernates on this
    # machine — its RTC wakealarm fires ~1s before the BOOTTIME timerfd
    # deadline, so the wake is treated as manual and s2h exits silently
    # (sleep.c: `if (!woken_by_timer) return 0;`); logind's 30s resume
    # holdoff then re-triggers the lid and the cycle restarts forever.
    #
    # How this hook works instead:
    #   pre suspend   on battery: remember a deadline in /run and arm every
    #                 RTC wakealarm (0 first, then the epoch — the standard
    #                 dance; arming all rtcN because the ACPI-bound one isn't
    #                 identifiable). On AC: no timer.
    #   post suspend  woke >60s before deadline → manual wake, clear the
    #                 alarm. Within the window + lid still closed + still on
    #                 battery → schedule a hibernate 3s out via a transient
    #                 unit. The deferral is mandatory: `systemctl hibernate`
    #                 from inside this hook is always refused by logind
    #                 ("Action suspend already in progress" — systemd 260
    #                 holds delayed_action until the suspend job completes,
    #                 which happens only after these hooks exit; observed
    #                 2026-09-06). Going through logind 3s later also lets
    #                 it arm delayed_action + the lid holdoff for the whole
    #                 hibernate write — the only protection against logind
    #                 re-triggering the closed lid into a concurrent suspend
    #                 mid-write. Lid open or on AC → clear, stay awake.
    #   pre hibernate zram keeps swapped pages resident in RAM; swap it out
    #                 to the disk swapfile so those pages are neither in the
    #                 image nor competing for free RAM (without this,
    #                 hibernate dies with -ENOMEM above ~9.5G use — kernel
    #                 log 2026-09-03). Best-effort: on swapoff failure,
    #                 hibernate anyway.
    #   post hibernate re-create zram via systemd-zram-setup@zram0.service
    #                 (covers resume AND failed/aborted hibernate attempts;
    #                 the pre-phase swapoff leaves the device at disksize 0,
    #                 so a plain swapon cannot work) and clear leftover
    #                 timer state.
    #
    # NixOS pitfall: system-sleep hooks run with a minimal PATH — `grep`
    # was missing while `swapon` happened to resolve (journal 2026-09-05),
    # so the PATH is set explicitly. SYSTEMD_SLEEP_ACTION (not $2) is the
    # action discriminator. Applies to lid AND GNOME idle suspends, both of
    # which are plain "suspend" on battery.
    etc."systemd/system-sleep/yoga-s2h".source = pkgs.writeShellScript "yoga-s2h" ''
      export PATH="${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.util-linux
          pkgs.systemd
        ]
      }:$PATH"

      DEADLINE_FILE=/run/yoga-s2h-deadline
      DELAY=7200 # suspend phase before hibernate (seconds)
      TOLERANCE=60 # wake within this window of the deadline = timer wake

      log() { echo "yoga-s2h: $*"; }
      on_ac() { [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)" = "1" ]; }
      lid_open() { grep -qs '^state:.*open' /proc/acpi/button/lid/*/state; }
      arm_rtcs() {
        armed=0
        for f in /sys/class/rtc/rtc*/wakealarm; do
          [ -w "$f" ] || continue
          echo 0 > "$f" 2>/dev/null
          echo "$1" > "$f" 2>/dev/null && armed=1
        done
        [ "$armed" = 1 ] || log "WARNING: failed to arm any RTC wakealarm"
      }
      disarm() {
        for f in /sys/class/rtc/rtc*/wakealarm; do
          [ -w "$f" ] || continue
          echo 0 > "$f" 2>/dev/null
        done
        rm -f "$DEADLINE_FILE"
      }

      case "$1:''${SYSTEMD_SLEEP_ACTION:-}" in
        recheck)
          # Deferred from post:hibernate via systemd-run: if the hibernate
          # attempt failed (unit in failed state) with the lid still closed
          # on battery, suspend again instead of sitting awake draining.
          if systemctl is-failed --quiet systemd-hibernate.service; then
            if lid_open; then
              log "hibernate failed but lid is open: leaving system awake"
            elif on_ac; then
              log "hibernate failed but on AC: leaving system awake"
            else
              log "hibernate failed with lid closed on battery: re-suspending (retry in 2h)"
              systemctl suspend
            fi
          fi
          ;;
        pre:suspend)
          if on_ac; then
            disarm
            log "suspend on AC: no hibernate timer"
          else
            deadline=$(( $(date +%s) + DELAY ))
            echo "$deadline" > "$DEADLINE_FILE"
            arm_rtcs "$deadline"
            log "suspend on battery: hibernate at $(date -d @"$deadline" 2>/dev/null || echo "$deadline")"
          fi
          ;;
        post:suspend)
          [ -r "$DEADLINE_FILE" ] || exit 0
          deadline=$(cat "$DEADLINE_FILE")
          now=$(date +%s)
          remaining=$(( deadline - now ))
          if [ "$remaining" -gt "$TOLERANCE" ]; then
            disarm
            log "manual wake ''${remaining}s before deadline: timer cleared"
          elif lid_open; then
            disarm
            log "timer reached but lid is open: staying awake"
          elif on_ac; then
            disarm
            log "timer reached but on AC: staying awake"
          else
            disarm
            log "suspend deadline reached: hibernating"
            if systemd-run --collect --unit=yoga-s2h-hibernate --on-active=3s systemctl hibernate; then
              log "hibernate deferred 3s via transient unit (logind refuses in-hook requests)"
            else
              log "WARNING: failed to schedule hibernate"
            fi
          fi
          ;;
        pre:hibernate)
          if grep -q '^/dev/zram0 ' /proc/swaps; then
            if swapoff /dev/zram0; then
              log "zram0 swapped out for hibernate image"
            else
              log "WARNING: swapoff /dev/zram0 failed, hibernating anyway"
            fi
          fi
          ;;
        post:hibernate)
          if [ -b /dev/zram0 ] && ! grep -q '^/dev/zram0 ' /proc/swaps; then
            # swapoff above auto-resets zram to disksize 0, so a plain
            # swapon fails ("could not read swap header", journal
            # 2026-09-06). Restart the generator's setup unit instead:
            # ExecStop (--reset-device) + ExecStart (--setup-device)
            # recreate size/algorithm/priority from the NixOS-generated
            # zram-generator.conf.
            if systemctl restart systemd-zram-setup@zram0.service; then
              log "zram0 re-created via systemd-zram-setup@zram0.service"
            else
              log "WARNING: re-creating zram0 failed; disk swapfile still active"
            fi
          fi
          # Self-heal after a failed/aborted hibernate (this branch also
          # runs then): schedule a recheck that re-suspends if the lid is
          # still closed on battery, so the machine doesn't sit awake
          # draining — the fresh cycle arms a new 2h deadline and retries.
          # The is-failed guard in the recheck makes it a no-op after a
          # successful resume.
          if ! lid_open && ! on_ac; then
            if systemd-run --collect --unit=yoga-s2h-recheck --on-active=15s -- /etc/systemd/system-sleep/yoga-s2h recheck; then
              log "failed-hibernate recheck scheduled (15s)"
            else
              log "WARNING: failed to schedule failed-hibernate recheck"
            fi
          fi
          disarm
          ;;
      esac
      exit 0
    '';

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
