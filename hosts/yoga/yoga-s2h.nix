{
  lib,
  pkgs,
  ...
}:
{
  # Self-implemented suspend-then-hibernate (the classic pre-systemd-252
  # pattern), because systemd 260's built-in s2h never hibernates on this
  # machine — its RTC wakealarm fires ~1s before the BOOTTIME timerfd
  # deadline, so the wake is treated as manual and s2h exits silently
  # (sleep.c: `if (!woken_by_timer) return 0;`); logind's 30s resume
  # holdoff then re-triggers the lid and the cycle restarts forever.
  #
  # HIBERNATION IS PARKED (2026-09-08; HIBERNATE_ENABLED=0 below). Ten
  # attempts across two nights, every one aborted in-place in the kernel
  # freeze pass ("usb 3-3: WARN: invalid context state", deep amdgpu
  # unwind — the drm/amd #5470 corruption precondition), regardless of
  # USB device/controller state (bound, idle, unbound, re-enumerated,
  # xHCI driver rebound) and regardless of bridging through a suspend
  # cycle first. The single 04:00 success never reproduced. Worse, the
  # aborts' device resets generate phantom power-button events that
  # GNOME turns into fresh hibernate requests — an abort→hibernate loop
  # until hard power-off (2026-09-08 00:20-00:21). So: suspend-only
  # (s2idle ≈0.25-0.5%/h → a full night ≈3-4%), abort detection and
  # depth-aware response kept for manual `systemctl hibernate` tests,
  # and re-enabling is a one-line flip after a kernel/BIOS update.
  # Full campaign post-mortem in REPO_OVERVIEW Known Gotchas.
  #
  # How this hook works:
  #   pre suspend   on battery: remember a deadline in /run and arm
  #                 every RTC wakealarm (0 first, then the epoch — the
  #                 standard dance; arming all rtcN because the
  #                 ACPI-bound one isn't identifiable). A still-valid
  #                 deadline from a previous cycle is kept
  #                 (spurious-wake path, see post suspend). On AC: no
  #                 timer.
  #   post suspend  woke >60s before deadline + lid open or AC →
  #                 manual wake, clear alarm and deadline. Woke >60s
  #                 early with lid closed on battery → spurious wake
  #                 (USB/BT etc.): clear only the alarm, KEEP the
  #                 deadline so the wake time doesn't slide +2h per
  #                 wake; logind's holdoff re-suspends and pre-suspend
  #                 re-arms the alarm. Within the window + lid still
  #                 closed + still on battery → hibernate if
  #                 HIBERNATE_ENABLED (deferred 3s via a transient
  #                 unit — `systemctl hibernate` from inside this hook
  #                 is always refused by logind, and going through it
  #                 3s later re-arms delayed_action + the lid holdoff
  #                 for the whole write), else disarm and let logind
  #                 re-suspend into a fresh window. Lid open or on AC →
  #                 clear, stay awake.
  #   pre hibernate stamp uptime+epoch for abort detection, then swap
  #                 zram out to the disk swapfile so those pages are
  #                 neither in the image nor competing for free RAM
  #                 (without this, hibernate dies with -ENOMEM above
  #                 ~9.5G use — kernel log 2026-09-03). Best-effort: on
  #                 swapoff failure, hibernate anyway.
  #   post hibernate re-create zram via systemd-zram-setup@zram0.service
  #                 (covers resume AND
  #                 aborted attempts; the pre-phase swapoff leaves the
  #                 device at disksize 0, so a plain swapon cannot
  #                 work), detect an in-place abort (uptime grew past
  #                 the threshold AND wall clock grew by the same — a
  #                 real resume's uptime also contains the frozen
  #                 reclaim+write time but its wall delta includes the
  #                 powered-off interval; see ABORT_UPTIME), and respond
  #                 by depth: amdgpu was suspended+unwound ("SMU is
  #                 resuming" in the kernel log) → reboot when
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
  environment.etc."systemd/system-sleep/yoga-s2h".source = pkgs.writeShellScript "yoga-s2h" ''
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
    DELAY=7200 # suspend window before (disabled) hibernate check (seconds)
    # Hibernate is PARKED after the 2026-09-07/08 campaign: 10+ attempts,
    # all aborted in the kernel freeze pass ("usb 3-3: WARN: invalid
    # context state", deep amdgpu unwind), regardless of USB
    # device/controller state or bridging through a suspend cycle (the
    # one 04:00 success never reproduced). Manual `systemctl hibernate`
    # still runs — the abort detection + depth-aware response below
    # still covers it. Flip to 1 to re-arm the automated deadline
    # hibernate (e.g. after a kernel or BIOS update). Full post-mortem
    # in REPO_OVERVIEW Known Gotchas.
    HIBERNATE_ENABLED=0
    # A hibernate attempt that runs entirely in this kernel (aborted in
    # place) grows /proc/uptime by the whole reclaim+snapshot+unwind
    # time, and the wall clock grows by the same (machine never powered
    # off): wall_grew - up_grew ≈ 0. On a REAL resume the restored
    # kernel's uptime also contains the reclaim+write time (it was
    # frozen into the image!), but the wall clock additionally contains
    # the powered-off interval + resume boot: wall_grew - up_grew ≥ 60s.
    # (Without the wall co-condition a clean resume would be misread as
    # a deep abort → auto-reboot after success; uptime alone cannot
    # separate the two — 2026-09-08 analysis.) Threshold 30s: a fast
    # 40s abort was missed by the old 45s cutoff (00:21 cycle), while
    # the pre-hook to poweroff path always exceeds ~30s.
    ABORT_UPTIME=30
    ABORT_WALL_SKEW=60
    TOLERANCE=60 # wake within this window of the deadline = timer wake
    # The kernel can abort a hibernate yet have the write() to
    # /sys/power/state return success — observed 2026-09-06 23:38 (usb
    # device failed during freeze-phase device suspend, no image
    # written, systemd-hibernate.service NOT failed, no error logged)
    # — so `systemctl is-failed` alone cannot detect kernel-level
    # aborts; it is kept only as a secondary trigger.

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
    # Post-mortem of the usb 3-3 (AX210 BT) hunt, kept so nobody retries
    # it: the "usb 3-3: WARN: invalid context state" abort could NOT be
    # fixed at the USB level — tried (2026-09-07/08): bound+active,
    # interface-unbound, device-unbound (→ usb_dev_restore -107
    # instead), bound+runtime-suspended via rfkill, device-level
    # authorized 0→1 re-enumeration, and a full xHCI controller driver
    # rebind — every hibernate from a running session aborted, and the
    # rebind demonstrably didn't change the WARN. What works: hibernate
    # started right after waking from s2idle (04:00 cycle). Hence the
    # bridge; the USB stack is left alone.

    case "$1:''${SYSTEMD_SLEEP_ACTION:-}" in
      recheck:*)
        # The transient unit runs the hook with $1=recheck and no
        # SYSTEMD_SLEEP_ACTION (that env var only exists in the real
        # system-sleep context), so the case word is "recheck:". A bare
        # "recheck)" pattern never matched and the abort response was
        # silently skipped (fixed 2026-09-09). "recheck:*" also covers a
        # hypothetical in-hook re-entry with an action set.
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
        elif [ "$HIBERNATE_ENABLED" != "1" ]; then
          # Hibernate parked → no RTC timer either: waking every 2h
          # just to re-suspend would cost ~0.4% battery per cycle for
          # nothing. A plain unbounded s2idle is the whole policy
          # while parked (~0.25-0.5%/h).
          disarm
          log "suspend on battery: hibernate parked, no RTC timer"
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
          if [ "$HIBERNATE_ENABLED" = "1" ]; then
            log "suspend deadline reached: hibernating"
            if systemd-run --collect --unit=yoga-s2h-hibernate --on-active=3s systemctl hibernate; then
              log "hibernate deferred 3s via transient unit (logind refuses in-hook requests)"
            else
              log "WARNING: failed to schedule hibernate"
            fi
          else
            # Hibernation parked (see HIBERNATE_ENABLED above): disarm
            # only — logind's lid holdoff re-suspends the closed lid and
            # pre:suspend opens a fresh 2h window. Costs ~30s awake per
            # 2h (~0.4% battery) while keeping the cycle observable in
            # the journal.
            log "suspend window elapsed (hibernate parked): re-suspending"
          fi
        fi
        ;;
      pre:hibernate)
        # Timestamps for abort detection in post:hibernate (see
        # ABORT_UPTIME). Written first: the zram swapoff below can take
        # minutes and all of it counts as in-kernel attempt time.
        printf '%s %s\n' "$(date +%s)" "$(now_uptime)" > "$HIBSTATE_FILE"
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
          # Abort iff the machine never powered off: uptime grew past
          # the attempt threshold AND the wall clock grew by the same
          # amount (wall-uptime skew < ABORT_WALL_SKEW). A real resume
          # has the same uptime growth (reclaim+write are frozen into
          # the image) but a much larger wall delta. See ABORT_UPTIME.
          up_grew=$(( $(now_uptime) - hib_uptime ))
          wall_grew=$(( $(date +%s) - hib_epoch ))
          if [ "$up_grew" -gt "$ABORT_UPTIME" ] && [ $(( wall_grew - up_grew )) -lt "$ABORT_WALL_SKEW" ]; then
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
}
