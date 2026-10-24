#!/usr/bin/env bash
# yoga-s2h sleep-hook simulation harness (runs INSIDE the test VM, as root).
#
# The hook is a state machine over /run files, sysfs/procfs power state and a
# handful of systemd tools. Simulating it without actually suspending needs:
#
#   * mount-namespace fakes for the inputs the hook reads:
#       /sys/class/power_supply/ADP0/online   (on_ac)
#       /sys/class/rtc/rtc0/wakealarm         (arm/clear RTC)
#       /proc/acpi/button/lid/LID0/state      (lid_open)
#       /proc/uptime                          (now_uptime / guard math)
#     These are bind-mounts of files under /tmp/s2h, so writes the hook
#     makes (wakealarm) persist for post-invocation asserts.
#   * shims for the tools it drives: the hook PREPENDS the real systemd and
#     util-linux store paths to PATH, so a PATH-based shim would be ignored —
#     instead the shims are bind-mounted OVER the real store binaries inside
#     the private namespace (systemctl, systemd-run, journalctl). swapoff
#     stays real: the node runs real zram swap, so the pre:hibernate swap-out
#     and the post:hibernate re-swap-on exercise the genuine code path.
#
# The scenarios below mirror the 2026-10-19 /tmp harness (59 asserts) that
# validated the open-lid two-window policy before it shipped.
set -u

HOOK=/etc/systemd/system-sleep/yoga-s2h
W=/tmp/s2h
M=$W/mode

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "PASS: $*"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
assert_contains() { # file needle desc
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3 (missing '$2' in $1)"; fi
}
assert_eq() { # desc want got
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$2' got '$3')"; fi
}
assert_file_val() { # desc file want
  assert_eq "$1" "$3" "$(cat "$2" 2>/dev/null || echo MISSING)"
}
assert_absent() { # desc file
  if [ ! -e "$2" ]; then ok "$1"; else bad "$1 ($2 still exists: $(cat "$2"))"; fi
}
assert_calls() { # desc regex
  if grep -qE -- "$2" "$W/calls.log" 2>/dev/null; then ok "$1"; else bad "$1 (no match for '$2' in calls.log)"; fi
}
assert_no_call() { # desc regex
  if grep -qE -- "$2" "$W/calls.log" 2>/dev/null; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi
}

reset_state() {
  rm -f /run/yoga-s2h-deadline /run/yoga-s2h-hibstate /run/yoga-s2h-decision /run/yoga-s2h-openlid
  rm -rf "$M"; mkdir -p "$M"
  : > "$W/calls.log"
  : > "$W/hook.log"
  printf '0\n' > "$W/psu/ADP0/online"      # battery
  printf 'state:   closed\n' > "$W/acpi/button/lid/LID0/state"
  printf '0\n' > "$W/rtc/rtc0/wakealarm"
  printf '10000.00 20000.00\n' > "$W/uptime"
}

# scenario knobs (call before run_hook)
set_ac()      { printf '%s\n' "$1" > "$W/psu/ADP0/online"; }
set_lid()     { printf 'state:   %s\n' "$1" > "$W/acpi/button/lid/LID0/state"; }
set_uptime()  { printf '%s.00 %s.00\n' "$1" "$1" > "$W/uptime"; }
set_deadline_rel() { date +%s | awk -v s="$1" '{ print $1 + s }' > /run/yoga-s2h-deadline; }

run_hook() { # phase action  — runs the real /etc hook under the namespace
  unshare --mount --propagation private bash "$W/ns-run.sh" "$2" \
    "$HOOK" "$1" "$2" > "$W/hook.log" 2>&1
}
run_hook_parked() { # phase action — HIBERNATE_ENABLED=0 sed-copy (parked mode)
  unshare --mount --propagation private bash "$W/ns-run.sh" "$2" \
    "$W/hook-parked" "$1" "$2" > "$W/hook.log" 2>&1
}
run_recheck() { # the transient unit path: $1=recheck, no SYSTEMD_SLEEP_ACTION
  unshare --mount --propagation private bash "$W/ns-run.sh" "" \
    "$HOOK" recheck > "$W/hook.log" 2>&1
}

echo "== s2h harness: setup =="
bash -n "$HOOK" && ok "hook passes bash -n" || bad "hook fails bash -n"
[ -x "$HOOK" ] && ok "hook is executable" || bad "hook not executable"

if [ ! -d /proc/acpi ]; then
  echo "HARNESS-ERROR: /proc/acpi missing in this kernel — lid faking impossible"
  exit 2
fi

# --- one-time workspace: fake inputs, shims, namespace wrapper ------------
rm -rf "$W"
mkdir -p "$M" "$W/shims" "$W/psu/ADP0" "$W/rtc/rtc0" "$W/acpi/button/lid/LID0"

# systemctl shim: records every call; controlled verdicts for the two
# probes the hook makes, and the swap-on side effect for the post:hibernate
# heal path.
cat > "$W/shims/systemctl" <<'EOS'
#!/usr/bin/env bash
M=/tmp/s2h/mode
echo "systemctl $*" >> /tmp/s2h/calls.log
case "$1" in
  is-failed)
    [ "$*" = "is-failed --quiet systemd-hibernate.service" ] && [ -f "$M/hib-failed" ] && exit 0
    exit 1
    ;;
  restart|start)
    if [ -f "$M/restart-swapon" ] && [[ "$*" == *"systemd-zram-setup@zram0.service"* ]]; then
      # The generator's teardown resets the device on swapoff, so a bare
      # swapon cannot work — seed an initialized device like the races do.
      if [ "$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)" = "0" ]; then
        echo 67108864 > /sys/block/zram0/disksize
      fi
      /run/current-system/sw/bin/mkswap /dev/zram0 >/dev/null 2>&1 || true
      /run/current-system/sw/bin/swapon /dev/zram0 2>>/tmp/s2h/calls.log \
        || echo "shim: swapon failed" >> /tmp/s2h/calls.log
    fi
    exit 0
    ;;
esac
exit 0
EOS

cat > "$W/shims/systemd-run" <<'EOS'
#!/usr/bin/env bash
echo "systemd-run $*" >> /tmp/s2h/calls.log
exit 0
EOS

# journalctl shim: deterministic monotonic clock (now_mono -> 1234) and an
# opt-in "SMU is resuming" kernel marker for the deep-abort branch.
cat > "$W/shims/journalctl" <<'EOS'
#!/usr/bin/env bash
M=/tmp/s2h/mode
if [[ "$*" == *"-k"* ]]; then
  [ -f "$M/smu" ] && echo "kernel: [   12.100000] amdgpu: SMU is resuming..."
  exit 0
fi
[ -f "$M/mono-empty" ] && exit 0
echo "[ 1234.567890] boot message"
exit 0
EOS
chmod +x "$W/shims/"*

# Namespace wrapper: private mounts, shims bound OVER the real systemd
# store binaries (the hook prepends that bin dir to PATH, so a PATH entry
# earlier/later cannot shadow them), fake sysfs/procfs inputs bound in
# (binds, so hook writes — the RTC wakealarm — persist for asserts).
cat > "$W/ns-run.sh" <<'EON'
#!/usr/bin/env bash
set -eu
W=/tmp/s2h
ACTION="$1"; shift
SYSDBIN=$(dirname "$(readlink -f "$(command -v systemctl)")")
for tool in systemctl systemd-run journalctl; do
  mount --bind "$W/shims/$tool" "$SYSDBIN/$tool"
done
mount --bind "$W/psu" /sys/class/power_supply
mount --bind "$W/rtc" /sys/class/rtc
mount --bind "$W/acpi" /proc/acpi
mount --bind "$W/uptime" /proc/uptime
if [ -n "$ACTION" ]; then
  exec env SYSTEMD_SLEEP_ACTION="$ACTION" "$@"
fi
exec "$@"
EON
chmod +x "$W/ns-run.sh"

# Parked-mode copy of the hook (only the HIBERNATE_ENABLED flag differs) —
# must be created after the workspace above exists.
sed -E 's/^[[:space:]]*HIBERNATE_ENABLED=1/    HIBERNATE_ENABLED=0/' "$HOOK" > "$W/hook-parked"
chmod +x "$W/hook-parked"
grep -q 'HIBERNATE_ENABLED=0' "$W/hook-parked" \
  && ok "parked hook copy created" || bad "parked hook copy not patched"

# ---------------------------------------------------------------------------
echo "== pre:suspend =="
reset_state
set_ac 1
run_hook pre suspend
assert_absent "P1 AC suspend arms no deadline" /run/yoga-s2h-deadline
assert_file_val "P1 AC suspend clears wakealarm" "$W/rtc/rtc0/wakealarm" 0
assert_contains "$W/hook.log" "no hibernate timer" "P1 logs no-timer"

reset_state
now=$(date +%s)
run_hook pre suspend
got=$(cat /run/yoga-s2h-deadline)
if [ "$((got - now))" -ge 7195 ] && [ "$((got - now))" -le 7205 ]; then
  ok "P2 battery suspend arms now+2h deadline"
else
  bad "P2 deadline off (got $got, now $now)"
fi
assert_file_val "P2 wakealarm armed to deadline" "$W/rtc/rtc0/wakealarm" "$got"
assert_contains "$W/hook.log" "suspend on battery" "P2 logs battery suspend"

reset_state
pending=$(date +%s | awk '{ print $1 + 3000 }')
echo "$pending" > /run/yoga-s2h-deadline
run_hook pre suspend
assert_file_val "P3 spurious-wake path keeps pending deadline" /run/yoga-s2h-deadline "$pending"
assert_contains "$W/hook.log" "keeping pending hibernate deadline" "P3 logs keep-deadline"

reset_state
run_hook_parked pre suspend
assert_absent "P4 parked mode arms nothing" /run/yoga-s2h-deadline
assert_contains "$W/hook.log" "hibernate parked, no RTC timer" "P4 logs parked"

# ---------------------------------------------------------------------------
echo "== post:suspend =="
reset_state
set_lid open
echo 2 > /run/yoga-s2h-openlid
set_deadline_rel 600
run_hook post suspend
assert_absent "S1 manual wake clears deadline" /run/yoga-s2h-deadline
assert_absent "S1 manual wake resets open-lid counter" /run/yoga-s2h-openlid
assert_file_val "S1 manual wake clears wakealarm" "$W/rtc/rtc0/wakealarm" 0
assert_contains "$W/hook.log" "manual wake" "S1 logs manual wake"

reset_state
set_deadline_rel 600
run_hook post suspend
[ -f /run/yoga-s2h-deadline ] && ok "S2 spurious wake keeps deadline" || bad "S2 deadline lost"
assert_file_val "S2 spurious wake clears wakealarm" "$W/rtc/rtc0/wakealarm" 0
assert_contains "$W/hook.log" "spurious wake" "S2 logs spurious wake"

reset_state
set_ac 1
set_lid open
set_deadline_rel 30
run_hook post suspend
assert_absent "S3 AC-at-deadline clears state" /run/yoga-s2h-deadline
assert_contains "$W/hook.log" "on AC: staying awake" "S3 logs AC stay-awake (lid open — AC wins)"

reset_state
set_lid open
set_deadline_rel 30
run_hook post suspend
assert_file_val "S4 window 1 increments counter" /run/yoga-s2h-openlid 1
assert_file_val "S4 records re-suspend decision" /run/yoga-s2h-decision openlid-resuspend
assert_calls "S4 schedules 15s recheck" "systemd-run .*unit=yoga-s2h-recheck.*on-active=15s"
assert_contains "$W/hook.log" "window 1/2 elapsed: re-suspending in 15s" "S4 logs window 1"

reset_state
set_lid open
echo 1 > /run/yoga-s2h-openlid
set_deadline_rel 30
run_hook post suspend
assert_absent "S5 window 2 consumes counter" /run/yoga-s2h-openlid
assert_calls "S5 defers hibernate 3s via transient unit" "systemd-run .*unit=yoga-s2h-hibernate.*on-active=3s.*systemctl hibernate"
assert_contains "$W/hook.log" "window 2/2 elapsed: hibernating" "S5 logs window 2"

reset_state
set_deadline_rel 30
run_hook post suspend
assert_calls "S6 lid-closed deadline defers hibernate" "systemd-run .*unit=yoga-s2h-hibernate.*systemctl hibernate"
assert_contains "$W/hook.log" "suspend deadline reached: hibernating" "S6 logs deadline hibernate"

reset_state
set_lid open
set_deadline_rel 30
run_hook_parked post suspend
assert_no_call "S7 parked open-lid schedules nothing" "systemd-run"
assert_contains "$W/hook.log" "hibernate parked" "S7 logs parked stay-awake"

reset_state
set_deadline_rel 30
run_hook_parked post suspend
assert_no_call "S8 parked deadline schedules nothing" "systemd-run"
assert_contains "$W/hook.log" "re-suspending" "S8 logs parked re-suspend"

# ---------------------------------------------------------------------------
echo "== recheck (transient unit path) =="
reset_state
echo openlid-resuspend > /run/yoga-s2h-decision
echo 1 > /run/yoga-s2h-openlid
set_ac 1
run_recheck
assert_no_call "R1 AC at recheck stays awake" "systemctl (suspend|reboot)"
assert_absent "R1 AC drops window counter" /run/yoga-s2h-openlid
assert_contains "$W/hook.log" "on AC, staying awake" "R1 logs AC stay-awake"

reset_state
echo openlid-resuspend > /run/yoga-s2h-decision
run_recheck
assert_calls "R2 recheck re-suspends" "systemctl suspend"
assert_contains "$W/hook.log" "re-suspending (next deadline hibernates)" "R2 logs re-suspend"

reset_state
echo reboot > /run/yoga-s2h-decision
run_recheck
assert_calls "R3 deep-abort recheck reboots" "systemctl reboot"

reset_state
echo resuspend > /run/yoga-s2h-decision
run_recheck
assert_calls "R4 shallow-abort recheck re-suspends" "systemctl suspend"

reset_state
echo reboot > /run/yoga-s2h-decision
set_lid open
run_recheck
assert_no_call "R5 lid open drops reboot decision" "systemctl reboot"
assert_contains "$W/hook.log" "lid is open, staying awake" "R5 logs lid-open stay-awake"

reset_state
run_recheck
assert_no_call "R6 no decision is a no-op" "systemctl"

# ---------------------------------------------------------------------------
echo "== pre:hibernate =="
# Real zram swap: the hook's swapout must actually run (util-linux is real).
reset_state
# The generator's ExecStop resets the device on every swapoff (BindsTo
# cascade), so a bare swapon cannot re-enable it — restart the real setup
# unit, which also runs the zram module's heal ExecStartPre (no-op here).
swap_on_zram() {
  grep -q '^/dev/zram0 ' /proc/swaps && return 0
  systemctl restart systemd-zram-setup@zram0.service
  for _ in 1 2 3 4 5; do
    grep -q '^/dev/zram0 ' /proc/swaps && return 0
    sleep 1
  done
  echo "swap_on_zram: zram0 swap did not come up" >&2
  return 1
}
swap_on_zram
run_hook pre hibernate
assert_contains "$W/hook.log" "zram0 swapped out for hibernate image" "H1 zram swapped out"
grep -q '^/dev/zram0 ' /proc/swaps && bad "H1 zram0 still swapped on" || ok "H1 zram0 actually swapped off"
if read -r h_ep h_up h_mono < /run/yoga-s2h-hibstate 2>/dev/null && [ -n "$h_mono" ]; then
  ok "H1 hibstate stamped with 3 fields"
else
  bad "H1 hibstate missing/incomplete: $(cat /run/yoga-s2h-hibstate 2>/dev/null)"
fi

reset_state
/run/current-system/sw/bin/swapoff /dev/zram0
run_hook pre hibernate
assert_contains "$W/hook.log" "-ENOMEM abort risk" "H2 warns about missing zram swapout"
[ -f /run/yoga-s2h-hibstate ] && ok "H2 hibstate still stamped" || bad "H2 hibstate missing"

# ---------------------------------------------------------------------------
echo "== post:hibernate =="
# journalctl shim pins now_mono=1234; fake uptime drives the math:
#   off_grew = (up - 1234) - (hib_up - hib_mono), up_grew = up - hib_up
reset_state
swap_on_zram
run_hook post hibernate
assert_contains "$W/hook.log" "zram0 already swapped on after resume" "B1 skips heal when swap active"
assert_no_call "B1 does not restart the setup unit" "systemctl restart"

reset_state
/run/current-system/sw/bin/swapoff /dev/zram0
touch "$M/restart-swapon"   # systemctl shim re-swaps zram0 on restart
run_hook post hibernate
assert_contains "$W/hook.log" "zram0 re-created via systemd-zram-setup@zram0.service" "B2 heals swap via setup unit"
assert_calls "B2 restarts the zram setup unit" "systemctl restart systemd-zram-setup@zram0"

reset_state
/run/current-system/sw/bin/swapoff /dev/zram0
run_hook post hibernate   # shim restart does NOT swap on -> poll must time out
assert_contains "$W/hook.log" "zram0 swap not active after resume" "B2b survives a failing heal"

# B3: real resume — off_grew 266s (up 2000, mono 1234, hib up 1000 mono 500)
reset_state
printf '1700000000 1000 500\n' > /run/yoga-s2h-hibstate
set_uptime 2000
run_hook post hibernate
assert_contains "$W/hook.log" "hibernate cycle completed" "B3 classifies real resume"

# B4: deep abort — off_grew 0, up_grew 734, SMU marker present
reset_state
printf '1700000000 1000 500\n' > /run/yoga-s2h-hibstate
set_uptime 1734
touch "$M/smu"
run_hook post hibernate
assert_file_val "B4 SMU abort decides reboot" /run/yoga-s2h-decision reboot
assert_calls "B4 defers reboot recheck 15s" "systemd-run .*unit=yoga-s2h-recheck.*on-active=15s"
assert_contains "$W/hook.log" "reboot pending" "B4 logs reboot pending"

# B5: shallow abort — no SMU marker
reset_state
printf '1700000000 1000 500\n' > /run/yoga-s2h-hibstate
set_uptime 1734
run_hook post hibernate
assert_file_val "B5 shallow abort decides resuspend" /run/yoga-s2h-decision resuspend
assert_contains "$W/hook.log" "shallow unwind" "B5 logs shallow abort"

# B6: secondary trigger — unit failed, no hibstate
reset_state
touch "$M/hib-failed"
run_hook post hibernate
assert_file_val "B6 failed unit triggers resuspend" /run/yoga-s2h-decision resuspend

# B7: monotonic unavailable
reset_state
printf '1700000000 1000 500\n' > /run/yoga-s2h-hibstate
set_uptime 1734
touch "$M/mono-empty"
run_hook post hibernate
assert_contains "$W/hook.log" "abort detection skipped" "B7 skips detection without monotonic clock"

echo "S2H-HARNESS: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
