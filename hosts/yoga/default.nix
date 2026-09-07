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
    #                 identifiable). A still-valid deadline from a previous
    #                 cycle is kept (spurious-wake path, see post suspend).
    #                 On AC: no timer.
    #   post suspend  woke >60s before deadline + lid open or AC → manual
    #                 wake, clear alarm and deadline. Woke >60s early with
    #                 lid closed on battery → spurious wake (USB/BT etc.):
    #                 clear only the alarm, KEEP the deadline so hibernate
    #                 time doesn't slide +2h per wake; logind's holdoff
    #                 re-suspends and pre-suspend re-arms the alarm.
    #                 Within the window + lid still closed + still on
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
    #   pre hibernate stamp uptime+epoch for abort detection, quiesce the
    #                 AX210's BT device 8087:0032 (rfkill + runtime-suspend
    #                 — the only state proven to survive all hibernate
    #                 device passes, see quiesce_btusb), then swap zram
    #                 out to the disk
    #                 swapfile so those pages are neither in the image nor
    #                 competing for free RAM (without this, hibernate dies
    #                 with -ENOMEM above ~9.5G use — kernel log 2026-09-03).
    #                 Best-effort: on swapoff failure, hibernate anyway.
    #   post hibernate rebind btusb, re-create zram via
    #                 systemd-zram-setup@zram0.service (covers resume AND
    #                 aborted attempts; the pre-phase swapoff leaves the
    #                 device at disksize 0, so a plain swapon cannot work),
    #                 detect an in-place abort (uptime grew >45s during the
    #                 attempt — a real resume restores the frozen clock),
    #                 and respond by depth: amdgpu was suspended+unwound
    #                 ("SMU is resuming" in the kernel log) → reboot when
    #                 unattended / warn when the user is present (TTM
    #                 corruption class, drm/amd #5470); shallow abort →
    #                 re-suspend and retry in 2h. Clear leftover timer
    #                 state either way.
    #
    # First full-cycle telemetry (2026-09-07 night): suspend 02:00, RTC
    # wake 04:00 to the second, image written, powered off ~11h, resumed
    # with amdgpu SMU clean — total battery cost 35%→34% (≈1%, s2idle
    # drain ≈0.25-0.5%/h). The 2h DELAY is cheap; no reason to shorten.
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
      HIBSTATE_FILE=/run/yoga-s2h-hibstate
      DECISION_FILE=/run/yoga-s2h-decision
      DELAY=7200 # suspend phase before hibernate (seconds)
      TOLERANCE=60 # wake within this window of the deadline = timer wake
      # A hibernate attempt that runs entirely in this kernel (aborted in
      # place) grows /proc/uptime by the whole reclaim+snapshot+unwind time
      # (minutes); a real resume restores the frozen kernel's timekeeping,
      # so uptime only grows by the image-load seconds. >45s in-kernel =
      # abort. This matters because the kernel can abort a hibernate yet
      # have the write() to /sys/power/state return success — observed
      # 2026-09-06 23:38 (usb device failed during freeze-phase device
      # suspend, no image written, systemd-hibernate.service NOT failed,
      # no error logged) — so `systemctl is-failed` alone cannot detect
      # kernel-level aborts; it is kept only as a secondary trigger.
      ABORT_UPTIME=45

      log() { echo "yoga-s2h: $*"; }
      on_ac() { [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)" = "1" ]; }
      lid_open() { grep -qs '^state:.*open' /proc/acpi/button/lid/*/state; }
      now_uptime() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
      arm_rtcs() {
        armed=0
        for f in /sys/class/rtc/rtc*/wakealarm; do
          [ -w "$f" ] || continue
          echo 0 > "$f" 2>/dev/null
          echo "$1" > "$f" 2>/dev/null && armed=1
        done
        [ "$armed" = 1 ] || log "WARNING: failed to arm any RTC wakealarm"
      }
      clear_alarms() {
        for f in /sys/class/rtc/rtc*/wakealarm; do
          [ -w "$f" ] || continue
          echo 0 > "$f" 2>/dev/null
        done
      }
      disarm() {
        clear_alarms
        rm -f "$DEADLINE_FILE"
      }
      # The AX210's Bluetooth USB device (8087:0032) breaks hibernate
      # whenever it is not runtime-idle at freeze time — with recent BT
      # activity its freeze/poweroff pass fails ("usb 3-3: WARN: invalid
      # context state", 2026-09-06 23:38 + 2026-09-07 22:02) and aborts
      # the hibernate mid-flight; the abort class that can corrupt
      # amdgpu/TTM state. Taking it off the bus is NOT an option either:
      # a driverless-but-registered usb device makes the poweroff/restore
      # pass return -ENOTCONN ("usb_dev_restore returns -107",
      # 2026-09-07 22:36 — deepest abort yet, after the snapshot cycle
      # had already completed). The only state proven to survive all
      # passes is BOUND + RUNTIME-SUSPENDED (the 2026-09-07 04:00
      # success: BT bound, idle for 2h). So: rfkill the controller, put
      # the device in autosuspend mode, and wait until it actually
      # suspends. Plain suspend is unaffected (suspend, not freeze).
      quiesce_btusb() {
        rfkill block bluetooth 2>/dev/null || true
        for v in /sys/bus/usb/devices/*/idVendor; do
          [ -e "$v" ] || continue
          dev=''${v%idVendor}
          dev=''${dev%/}
          if [ "$(cat "$v" 2>/dev/null)" = "8087" ] && [ "$(cat "$dev/idProduct" 2>/dev/null)" = "0032" ]; then
            echo auto > "$dev/power/control" 2>/dev/null || true
            i=0
            while [ "$i" -lt 10 ] && [ "$(cat "$dev/power/runtime_status" 2>/dev/null)" != "suspended" ]; do
              sleep 1
              i=$(( i + 1 ))
            done
            log "8087:0032 at freeze: $(cat "$dev/power/runtime_status" 2>/dev/null || echo unknown) (after ''${i}s)"
          fi
        done
      }
      unquiesce_btusb() {
        rfkill unblock bluetooth 2>/dev/null || true
      }

      case "$1:''${SYSTEMD_SLEEP_ACTION:-}" in
        recheck)
          # Deferred from post:hibernate via systemd-run (logind refuses
          # in-hook sleep/reboot requests). Acts on the decision recorded
          # there, re-checked against fresh lid/AC state at fire time.
          [ -r "$DECISION_FILE" ] || exit 0
          decision=$(cat "$DECISION_FILE")
          rm -f "$DECISION_FILE"
          if lid_open; then
            log "post-abort recheck: lid is open, staying awake ($decision dropped)"
          elif on_ac; then
            log "post-abort recheck: on AC, staying awake ($decision dropped)"
          elif [ "$decision" = "reboot" ]; then
            log "rebooting after deep-aborted hibernate (amdgpu was suspended+unwound)"
            systemctl reboot
          else
            log "re-suspending after aborted hibernate (hibernate retry in 2h)"
            systemctl suspend
          fi
          ;;
        pre:suspend)
          if on_ac; then
            disarm
            log "suspend on AC: no hibernate timer"
          else
            now=$(date +%s)
            deadline=""
            if [ -r "$DEADLINE_FILE" ]; then
              pending=$(cat "$DEADLINE_FILE")
              # A wake with the lid still closed wasn't the user (see
              # post:suspend) — keep the original deadline instead of
              # pushing hibernation out by another full DELAY per
              # spurious wake.
              if [ "$pending" -gt "$now" ] 2>/dev/null && ! lid_open; then
                deadline=$pending
                log "keeping pending hibernate deadline (spurious-wake path)"
              fi
            fi
            if [ -z "$deadline" ]; then
              deadline=$(( now + DELAY ))
            fi
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
            if lid_open || on_ac; then
              disarm
              log "manual wake ''${remaining}s before deadline: timer cleared"
            else
              # Lid still closed + still on battery + far from the
              # deadline = spurious wake (USB/BT device, etc.), not the
              # user. Clear only the RTC alarm (pre:suspend on logind's
              # re-suspend re-arms it); KEEP the deadline file so the
              # hibernate time doesn't slide out by 2h per wake.
              clear_alarms
              log "spurious wake ''${remaining}s before deadline: deadline kept, will re-suspend"
            fi
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
          # Timestamps for abort detection in post:hibernate (see
          # ABORT_UPTIME). Written first: the zram swapoff below can take
          # minutes and all of it counts as in-kernel attempt time.
          printf '%s %s\n' "$(date +%s)" "$(now_uptime)" > "$HIBSTATE_FILE"
          quiesce_btusb
          if grep -q '^/dev/zram0 ' /proc/swaps; then
            if swapoff /dev/zram0; then
              log "zram0 swapped out for hibernate image"
            else
              log "WARNING: swapoff /dev/zram0 failed, hibernating anyway"
            fi
          fi
          ;;
        post:hibernate)
          unquiesce_btusb
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
          # Abort detection + proportional response. Two depths, from the
          # two observed aborts:
          #   shallow (2026-09-06 23:38): a USB device failed during
          #     freeze-phase device suspend, amdgpu never suspended, the
          #     machine ran all night afterwards without incident.
          #   deep (2026-09-06 01:26 incident): amdgpu DID suspend and was
          #     unwound — that state carries the TTM LRU corruption that
          #     oopsed 20 min later and hard-locked the machine (drm/amd
          #     #5470 class). Marker: "SMU is resuming" in the kernel log
          #     since the attempt started = amdgpu went down and came back.
          # Deep abort, unattended (lid closed, battery): reboot — the
          # documented mitigation, and a hard lock loses the session
          # anyway. Deep abort with the user present (lid open/AC): warn
          # loudly and stay up. Shallow abort unattended: re-suspend and
          # retry in 2h. On a clean resume none of this triggers.
          decision=""
          if [ -r "$HIBSTATE_FILE" ]; then
            read -r hib_epoch hib_uptime < "$HIBSTATE_FILE"
            rm -f "$HIBSTATE_FILE"
            if [ $(( $(now_uptime) - hib_uptime )) -gt "$ABORT_UPTIME" ]; then
              if journalctl -k --no-pager --since "@$hib_epoch" 2>/dev/null | grep -q "SMU is resuming"; then
                decision=reboot
              else
                decision=resuspend
              fi
            fi
          fi
          # Secondary trigger: attempts systemd itself failed (e.g. the
          # 2026-09-03 -ENOMEM abort, too fast for the uptime check).
          if [ -z "$decision" ] && systemctl is-failed --quiet systemd-hibernate.service; then
            decision=resuspend
          fi
          if [ -n "$decision" ]; then
            echo "$decision" > "$DECISION_FILE"
            if [ "$decision" = "reboot" ]; then
              log "hibernate aborted AFTER amdgpu suspend (TTM corruption risk): reboot pending"
              wall "yoga-s2h: hibernate aborted mid-GPU-suspend; rebooting to avoid amdgpu/TTM corruption (drm/amd #5470 class)" 2>/dev/null || true
            else
              log "hibernate aborted in-kernel (shallow unwind): re-suspend pending"
            fi
            if ! lid_open && ! on_ac; then
              if systemd-run --collect --unit=yoga-s2h-recheck --on-active=15s -- /etc/systemd/system-sleep/yoga-s2h recheck; then
                log "abort response ($decision) deferred 15s"
              else
                log "WARNING: failed to schedule abort recheck"
              fi
            else
              log "lid open or on AC after aborted hibernate: leaving system awake"
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
