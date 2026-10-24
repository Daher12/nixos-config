# ZRAM Swap Configuration
# vm.swappiness=100: With zram, high swappiness is optimal - prefer compressed RAM over disk
# vm.page-cluster=0: Disable readahead for swap; zram is random-access, not sequential
# vm.watermark_boost_factor=0: Disable watermark boosting; unnecessary with fast zram

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.zram;
in
{
  options.features.zram = {
    enable = lib.mkEnableOption "ZRAM swap";

    memoryPercent = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Percentage of RAM to use for ZRAM";
    };
  };

  config = lib.mkIf cfg.enable {
    zramSwap = {
      enable = true;
      algorithm = "lz4";
      inherit (cfg) memoryPercent;
      priority = 10;
      swapDevices = 1;
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault 100;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.vfs_cache_pressure" = lib.mkDefault 100;
      "vm.page-cluster" = lib.mkDefault 0;
    };

    # zram-generator cannot set up an already-initialized device (EBUSY on
    # comp_algorithm; nixpkgs's own comment on this template cites
    # systemd/zram-generator#226), so any unclean teardown leaves zram swap
    # dead: a switch whose regenerated dev-zram0.swap gets restarted by
    # switch-to-configuration drags the service down via the generator's
    # BindsTo (yoga, 2026-10-18: stuck at 14.8G initialized, no swap, from a
    # nixpkgs bump), and the s2h resume race hits the same state. nixpkgs
    # already pins restartIfChanged=false on this template so s-t-c skips the
    # service itself; the swap unit still gets restarted, and this
    # template-level ExecStartPre heals the residue before every setup.
    #
    # Kernel 7.2.9 semantics (proven by journal 2026-10-19 00:46:20): a reset
    # REMOVES a hot-added device — `zramctl --reset` logged "zram: Removed
    # device: zram0" and the follow-up setup died with ENOENT on
    # comp_algorithm. So resetting is not enough: after a reset (or if the
    # device is missing entirely) re-create it via
    # /sys/class/zram-control/hot_add — the same knob zram-generator itself
    # uses at boot. On kernels where a reset merely clears the device, the
    # hot_add step is skipped (device still present, disksize 0). No-op on a
    # fresh device at boot (disksize 0); never touches an in-use device.
    #
    # Template-level ("systemd-zram-setup@") ON PURPOSE: an instance-level
    # def ("systemd-zram-setup@zram0") makes NixOS emit a standalone
    # systemd-zram-setup@zram0.service that SHADOWS the upstream template —
    # an ExecStart-less one-shot that systemd outright refuses ("Service has
    # no ExecStart=", generation 187, 2026-10-19). Template-level merges into
    # the template's overrides.conf next to nixpkgs's own settings and
    # inherits its util-linux PATH; %i carries the instance name.
    systemd.services."systemd-zram-setup@".serviceConfig.ExecStartPre =
      pkgs.writeShellScript "zram-reset-if-stale" ''
        dev="''${1:?instance name required}"
        if [ -e "/sys/block/$dev" ]; then
          disksize=$(cat "/sys/block/$dev/disksize" 2>/dev/null || echo 0)
          # Fresh device (normal boot) or in-use device: nothing to heal.
          if [ "$disksize" -eq 0 ] || grep -q "^/dev/$dev " /proc/swaps; then
            exit 0
          fi
          echo "$dev initialized without swap (stale teardown residue) - resetting"
          # The reset removes the device on this kernel; fall through to the
          # re-create below. Sysfs fallback in case zramctl is unavailable.
          zramctl --reset "/dev/$dev" 2>/dev/null || echo 1 > "/sys/block/$dev/reset"
        fi
        if ! [ -e "/sys/block/$dev" ]; then
          new_id=$(cat /sys/class/zram-control/hot_add) || {
            echo "WARNING: could not re-create $dev via zram-control/hot_add" >&2
            exit 1
          }
          if [ "zram$new_id" != "$dev" ]; then
            echo "WARNING: hot_add created zram$new_id, expected $dev - removing it again" >&2
            echo "$new_id" > /sys/class/zram-control/hot_remove
            exit 1
          fi
          echo "$dev re-created via zram-control/hot_add"
        fi
      ''
      + " %i";
  };
}
