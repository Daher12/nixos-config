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
  # RE-ARMED 2026-10-18 (HIBERNATE_ENABLED=1 below). The "every hibernate
  # aborts" narrative was an artifact of the abort detector, not the
  # kernel: this kernel INJECTS the hibernation off-time into
  # CLOCK_BOOTTIME at resume, so a completed cycle ends with
  # uptime == wall-since-boot — which the old wall-vs-uptime-skew logic
  # read as "never powered off ⇒ in-place abort". Two verified real
  # cycles on 7.2.9-zen1 (2026-10-17 13:49 off ≈50s; 2026-10-18 00:24 off
  # ≈10min — itself misclassified as a deep abort, surviving only because
  # the lid was open) prove hibernate works on the fix-bearing kernel.
  # The usb 3-3 WARN, the "SMU is resuming" replay and the same-second
  # journal stamps are all NORMAL for a completed cycle. CVE-2026-98166
  # (TTM bulk_move UAF) is still fixed and worth having — 14+ clean
  # resumes/unwinds since, zero delayed oopses.
  # Re-arm discipline: run one supervised manual `systemctl hibernate`
  # first and expect the hook to log "hibernate cycle completed"; the
  # automated path only fires after a 2h battery suspend anyway. Full
  # campaign post-mortem in REPO_OVERVIEW Known Gotchas.
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
  #                 re-suspend into a fresh window. Within the window
  #                 + lid open + battery (the idle-suspend case,
  #                 2026-10-19): the first elapsed window re-suspends
  #                 15s out via the recheck transient unit — the
  #                 machine is awake ~15s per cycle instead of the old
  #                 "stay awake until hypridle re-suspends" — and the
  #                 SECOND consecutive elapsed window hibernates, so
  #                 an idle suspend left >2×DELAY unattended still
  #                 reaches disk. Manual wake, AC, a completed cycle
  #                 or a reboot resets the window counter. On AC →
  #                 clear, stay awake.
  #   pre hibernate stamp uptime+epoch for abort detection, then swap
  #                 zram out to the disk swapfile so those pages are
  #                 neither in the image nor competing for free RAM
  #                 (without this, hibernate dies with -ENOMEM above
  #                 ~9.5G use — kernel log 2026-09-03). Best-effort: on
  #                 swapoff failure, hibernate anyway.
  #   post hibernate re-create zram via systemd-zram-setup@zram0.service
  #                 (covers resume AND aborted attempts; the pre-phase
  #                 swapoff leaves the device at disksize 0, so a plain
  #                 swapon cannot work; a resume race that leaves the
  #                 device initialized-but-not-swapped is handled by
  #                 reset + start, see post:hibernate), classify the
  #                 outcome (real resume ⇒
  #                 BOOTTIME−MONOTONIC divergence grew by the off-time,
  #                 logged as "cycle completed"; in-place abort ⇒
  #                 divergence unchanged + uptime growth > 30s — see
  #                 ABORT DETECTION below) and respond by depth on
  #                 aborts: amdgpu was suspended+unwound ("SMU is
  #                 resuming" in the kernel log) → reboot when
  #                 unattended / warn when the user is present (TTM
  #                 corruption class, drm/amd #5470); shallow abort →
  #                 re-suspend and retry in 2h. Clear leftover timer
  #                 state either way.
  #
  # The 2h timer is deliberately long — a full cycle costs ≈1% battery
  # (measured 2026-09-07: 11h powered off, 35%→34%), so there is no reason
  # to shorten it.
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
    OPENLID_FILE=/run/yoga-s2h-openlid
    DELAY=7200 # suspend phase before hibernate (seconds)
    # HIBERNATE_ENABLED gates the automated deadline hibernate (the 2h
    # window armed in pre:suspend). Re-armed 2026-10-18: two verified
    # real cycles on 7.2.9-zen1 (2026-10-17 13:49 off ≈50s, 2026-10-18
    # 00:24 off ≈10min — the "attempts #14+ always abort" narrative was
    # an artifact of the broken abort detector, see ABORT DETECTION
    # below; hibernate appears to WORK on this kernel). Supervised-test
    # advice: run one manual `systemctl hibernate` first and expect the
    # hook to log "hibernate cycle completed"; the automated path arms
    # only after a 2h battery suspend, so re-arming commits nothing
    # until then. Flip to 0 to re-park.
    HIBERNATE_ENABLED=1
    # Open-lid (idle-suspend) deadline policy (2026-10-19): window 1
    # re-suspends 15s out (see recheck:), window MAX_OPENLID hibernates.
    # The counter in OPENLID_FILE counts CONSECUTIVE elapsed windows —
    # cleared on manual wake, AC suspend, a completed hibernate and
    # reboot (tmpfs) — so a briefly-away machine stays in cheap s2idle
    # and only an idle suspend left unattended for >MAX_OPENLID×DELAY
    # pays for a full hibernate.
    MAX_OPENLID=2
    # ABORT DETECTION (rewritten 2026-10-18 after a proven false
    # positive): this kernel INJECTS the hibernation off-time into
    # CLOCK_BOOTTIME (/proc/uptime) at resume — verified live: both real
    # cycles ended with uptime == wall-since-boot, which the old
    # wall-vs-uptime-skew logic read as "never powered off" and
    # misclassified a SUCCESS as a deep abort ("reboot pending" — it
    # survived only because the lid was open; unattended it would have
    # rebooted a perfectly restored machine). Correct discriminator:
    # CLOCK_MONOTONIC never includes injected or suspended time, so the
    # BOOTTIME−MONOTONIC divergence grows by the off-duration on a real
    # resume and is unchanged on an in-place abort:
    #   real resume    ⇒ off_grew > RESUME_OFF_MIN (fastest power press
    #                    + POST + restore ≥ ~25s in practice)
    #   in-place abort ⇒ off_grew ≈ 0 AND up_grew > ABORT_UPTIME (the
    #                    whole reclaim/snapshot/unwind ran in-kernel)
    # If monotonic can't be read, detection is skipped entirely
    # (fail-safe: no reboot decision on missing data).
    ABORT_UPTIME=30
    RESUME_OFF_MIN=10
    TOLERANCE=60 # wake within this window of the deadline = timer wake
    # The kernel can abort a hibernate yet have the write() to
    # /sys/power/state return success — observed 2026-09-06 23:38 (usb
    # device failed during freeze-phase device suspend, no image
    # written, systemd-hibernate.service NOT failed, no error logged)
    # — so `systemctl is-failed` alone cannot detect kernel-level
    # aborts; it is kept only as a secondary trigger.

    log() { echo "yoga-s2h: $*"; }
    on_ac() {
      # Glob, not a hardcoded ADP0: both companion probes (pkgs/is-on-ac,
      # ryzen-tdp) glob too — a firmware/driver supply rename must not
      # silently read "battery" forever (the RTC deadline would then be
      # armed on AC, the exact state the guards exist to prevent).
      for f in /sys/class/power_supply/*/online; do
        [ -r "$f" ] || continue
        [ "$(cat "$f" 2>/dev/null)" = "1" ] && return 0
      done
      return 1
    }
    lid_open() { grep -qs '^state:.*open' /proc/acpi/button/lid/*/state; }
    now_uptime() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
    # CLOCK_MONOTONIC seconds, taken from the newest journal record's
    # kernel timestamp (no plain-shell clock exposes monotonic). Prints
    # nothing on failure — callers must treat that as "detection
    # unavailable".
    now_mono() { journalctl -n 1 --no-pager -o short-monotonic 2>/dev/null | grep -oE '\[[ ]*[0-9]+\.' | tr -d '[ .'; }
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
    # rebind demonstrably didn't change the WARN. The bridge through a
    # suspend cycle failed identically (2026-10-17 attempt #14, on a
    # kernel carrying the CVE-2026-98166 fix), so the "only hibernate
    # right after an s2idle wake" theory was wrong too. The USB WARN is
    # a symptom of the abort, not its cause: the abort happens earlier,
    # in the amdgpu/ACPI S4 entry path (see header), and the WARN is just
    # noise while unwinding. The USB stack is left alone.

    case "$1:''${SYSTEMD_SLEEP_ACTION:-}" in
      recheck:*)
        # The transient unit runs the hook with $1=recheck and no
        # SYSTEMD_SLEEP_ACTION (that env var only exists in the real
        # system-sleep context), so the case word is "recheck:". A bare
        # "recheck)" pattern never matched and the abort response was
        # silently skipped (fixed 2026-09-09). "recheck:*" also covers a
        # hypothetical in-hook re-entry with an action set.
        # Deferred from post:suspend (open-lid window 1) and
        # post:hibernate (abort response) via systemd-run (logind
        # refuses in-hook sleep/reboot requests). Acts on the decision
        # recorded there, re-checked against fresh lid/AC state at
        # fire time.
        [ -r "$DECISION_FILE" ] || exit 0
        decision=$(cat "$DECISION_FILE")
        rm -f "$DECISION_FILE"
        if [ "$decision" = "openlid-resuspend" ]; then
          # Open-lid window 1 re-suspend: lid open is the EXPECTED
          # state here (checked before the post-abort guard, which
          # would drop the decision), so only AC cancels — plugging
          # in mid-window means no hibernate is needed. The fresh
          # suspend arms window 2 via pre:suspend. AC also ends the
          # episode: clear the window counter, same as every other
          # AC/manual-wake exit, so the next battery episode starts
          # at window 1 again.
          if on_ac; then
            rm -f "$OPENLID_FILE"
            log "open-lid recheck: on AC, staying awake (window cycle dropped)"
          else
            log "open-lid recheck: re-suspending (next deadline hibernates)"
            systemctl suspend
          fi
        elif lid_open; then
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
          rm -f "$OPENLID_FILE"
          log "suspend on AC: no hibernate timer"
        elif [ "$HIBERNATE_ENABLED" != "1" ]; then
          # Hibernate parked → no RTC timer either: waking every 2h
          # just to re-suspend would cost ~0.4% battery per cycle for
          # nothing. A plain unbounded s2idle is the whole policy
          # while parked (~0.25-0.5%/h).
          disarm
          rm -f "$OPENLID_FILE"
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
            rm -f "$OPENLID_FILE"
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
        elif on_ac; then
          # Checked BEFORE the lid-open branch: AC plugged mid-window
          # (without waking the machine) must keep the machine awake
          # whatever the lid says — the window logic below must never
          # hibernate or re-suspend on AC.
          disarm
          rm -f "$OPENLID_FILE"
          log "timer reached but on AC: staying awake"
        elif lid_open; then
          # Idle-suspend deadline with the lid open (2026-10-19): the
          # old behavior ("staying awake") left the machine up until
          # hypridle's 2h idle timer fired — screen lit ~10min of it,
          # ~0.5%/h on battery. Now: window 1 re-suspends 15s out via
          # the recheck transient unit, window MAX_OPENLID hibernates
          # through the same deferred unit as the lid-closed path. The
          # counter counts elapsed windows INCLUDING this one, so the
          # compare happens after the increment (an earlier
          # compare-then-increment draft hibernated only at the third
          # deadline — caught by the /tmp/s2h-harness simulation).
          disarm
          if [ "$HIBERNATE_ENABLED" != "1" ]; then
            log "timer reached but lid is open: staying awake (hibernate parked)"
          else
            openlid_count=$(cat "$OPENLID_FILE" 2>/dev/null || echo 0)
            openlid_count=$((openlid_count + 1))
            if [ "$openlid_count" -ge "$MAX_OPENLID" ]; then
              rm -f "$OPENLID_FILE"
              log "lid open, window $openlid_count/$MAX_OPENLID elapsed: hibernating"
              if systemd-run --collect --unit=yoga-s2h-hibernate --on-active=3s systemctl hibernate; then
                log "hibernate deferred 3s via transient unit (logind refuses in-hook requests)"
              else
                log "WARNING: failed to schedule hibernate"
              fi
            else
              echo "$openlid_count" > "$OPENLID_FILE"
              log "lid open, window $openlid_count/$MAX_OPENLID elapsed: re-suspending in 15s"
              echo openlid-resuspend > "$DECISION_FILE"
              if ! systemd-run --collect --unit=yoga-s2h-recheck --on-active=15s -- /etc/systemd/system-sleep/yoga-s2h recheck; then
                log "WARNING: failed to schedule re-suspend"
              fi
            fi
          fi
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
        # Timestamps for abort detection in post:hibernate (see ABORT
        # DETECTION above). Written first: the zram swapoff below can take
        # minutes and all of it counts as in-kernel attempt time.
        printf '%s %s %s\n' "$(date +%s)" "$(now_uptime)" "$(now_mono)" > "$HIBSTATE_FILE"
        if grep -q '^/dev/zram0 ' /proc/swaps; then
          if swapoff /dev/zram0; then
            log "zram0 swapped out for hibernate image"
          else
            log "WARNING: swapoff /dev/zram0 failed, hibernating anyway"
          fi
        else
          # Silent-skip trap (2026-10-18): after the zram re-create race
          # left zram off, this grep quietly failed and the image would
          # have been taken WITH zram pages resident in RAM — the
          # 2026-09-03 -ENOMEM abort setup above ~9.5G use. Make it loud.
          log "WARNING: zram0 not swapped on - hibernating without the zram swap-out; -ENOMEM abort risk above ~9.5G RAM use"
        fi
        ;;
      post:hibernate)
        # Resume-side race (2026-10-18 19:59:11): ~22ms after hibernation
        # exit something re-initialized zram0 (correct size + lz4) BEFORE
        # this hook's restart ran, so the generator's first write failed
        # with "Can't change algorithm for initialized device" (EBUSY) and
        # never reached mkswap/swapon — zram swap stayed off until the
        # next reboot. Let such an instance settle, then only act if zram
        # is still not swapped on.
        sleep 2
        if grep -q '^/dev/zram0 ' /proc/swaps; then
          log "zram0 already swapped on after resume"
        else
          # Residue handling lives in the setup unit's template ExecStartPre
          # now (modules/features/zram.nix): reset a stale-initialized device
          # and re-create it via zram-control/hot_add. On this kernel (7.2.9)
          # a reset REMOVES the hot-added device ("zram: Removed device:
          # zram0", journal 2026-10-19 00:46), so the hook's old manual
          # `zramctl --reset` + plain start left NO device for the setup to
          # configure — ENOENT instead of the EBUSY it was written for. The
          # unit owns the whole dance; restart = generator reset-device
          # (no-op on an unconfigured device) + healed start.
          if ! [ -b /dev/zram0 ]; then
            log "zram0 missing after resume - re-creating via systemd-zram-setup@zram0 (hot_add)"
          fi
          if ! systemctl restart systemd-zram-setup@zram0.service; then
            systemctl start systemd-zram-setup@zram0.service \
              || log "WARNING: zram setup unit failed twice after resume"
          fi
          # Truth is /proc/swaps, not the setup unit's exit code: the
          # swapon rides the setup unit's transaction (observed 2026-10-18
          # 01:12, and via "Dependency failed for Compressed Swap" at
          # 19:59) and lags it by ~0.1s, but the dependency chain is
          # generator-managed — poll for the actual swapon, poke the swap
          # unit directly once if the chain stalls, and report the real
          # end state either way.
          waited=0
          while [ "$waited" -lt 5 ] && ! grep -q '^/dev/zram0 ' /proc/swaps; do
            if [ "$waited" = "2" ]; then
              systemctl start dev-zram0.swap 2>/dev/null
            fi
            sleep 1
            waited=$((waited + 1))
          done
          if grep -q '^/dev/zram0 ' /proc/swaps; then
            log "zram0 re-created via systemd-zram-setup@zram0.service"
          else
            log "WARNING: zram0 swap not active after resume; disk swapfile still active"
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
          read -r hib_epoch hib_uptime hib_mono < "$HIBSTATE_FILE"
          rm -f "$HIBSTATE_FILE"
          mono_now=$(now_mono)
          if [ -n "$mono_now" ] && [ -n "$hib_mono" ]; then
            # BOOTTIME−MONOTONIC divergence before vs after: a real
            # resume injects the powered-off interval into BOOTTIME only,
            # so the divergence grows by the off-duration; an in-place
            # abort advances both clocks equally. See ABORT DETECTION.
            off_grew=$(( ($(now_uptime) - mono_now) - (hib_uptime - hib_mono) ))
            up_grew=$(( $(now_uptime) - hib_uptime ))
            if [ "$off_grew" -gt "$RESUME_OFF_MIN" ]; then
              log "hibernate cycle completed (powered off ≈''${off_grew}s)"
            elif [ "$up_grew" -gt "$ABORT_UPTIME" ]; then
              if journalctl -k --no-pager --since "@$hib_epoch" 2>/dev/null | grep -q "SMU is resuming"; then
                decision=reboot
              else
                decision=resuspend
              fi
            fi
          else
            log "WARNING: monotonic clock unavailable — abort detection skipped"
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
        # A completed cycle (or abort) ends the open-lid episode; the
        # next one starts fresh at window 1.
        rm -f "$OPENLID_FILE"
        ;;
    esac
    exit 0
  '';
}
