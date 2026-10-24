# NixOS VM test for the zram stale-teardown heal in modules/features/zram.nix.
#
# The template-level ExecStartPre on systemd-zram-setup@ exists because two
# production incidents (yoga 2026-10-18/19) left zram0 initialized but not
# swapped: a switch-restarted dev-zram0.swap and the s2h resume race. The
# ExecStartPre resets such a device and — because kernel 7.2.9-zen REMOVES a
# hot-added device on reset — re-creates it via /sys/class/zram-control/
# hot_add. This test reproduces both residue shapes on the VM kernel (where
# reset keeps the device) and proves the unit heals back to active swap:
#
#   1. healthy boot               → zram0 active swap (baseline)
#   2. initialized-but-not-swapped→ reset path, swap restored
#   3. device removed entirely    → hot_add path, swap restored
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.zram-heal
{
  testers,
  zramModule,
}:

{
  zram-heal = testers.runNixOSTest {
    name = "zram-heal";

    nodes.machine =
      { ... }:
      {
        _module.args.mainUser = "root";
        imports = [ zramModule ];

        # Small zram: swapoff during the heal scenarios is instant.
        features.zram = {
          enable = true;
          memoryPercent = 5;
        };
      };

    testScript = ''
      start_all()

      machine.wait_for_unit("multi-user.target")

      def swaps():
          return machine.succeed("grep '^/dev/zram0 ' /proc/swaps || true").strip()

      def heal_unit_journal():
          return machine.succeed("journalctl -b -u systemd-zram-setup@zram0.service --no-pager | tail -20")

      # --- 1. Healthy boot: zram0 must be active swap -------------------
      assert "/dev/zram0 " in swaps(), "zram0 not swapped on after boot"
      machine.succeed("systemctl is-active dev-zram0.swap")

      # The heal script must be merged into the template (template-level,
      # not instance-level — an instance-level def would shadow the
      # upstream template; see the module comment).
      unit_dump = machine.succeed("systemctl cat systemd-zram-setup@zram0.service")
      assert "zram-reset-if-stale" in unit_dump, "ExecStartPre heal script not wired into the template"

      # --- 2. Stale residue: initialized but not swapped -----------------
      # This is the exact state both 2026-10-18 incidents left behind
      # (14.8G initialized device, no swap). A plain swapoff does NOT
      # reproduce it in the VM: the generator's BindsTo stops the setup
      # unit, whose ExecStop resets the device ("capacity change ... to
      # 0"). The residue only forms when that teardown is skipped (the
      # switch-restart and s2h resume races) — so seed it the way those
      # races leave it: swapoff, then re-initialize the device by hand.
      machine.succeed("swapoff /dev/zram0")
      machine.wait_until_succeeds("test \"$(cat /sys/block/zram0/disksize)\" = 0")
      machine.succeed("echo 67108864 > /sys/block/zram0/disksize")
      assert swaps() == "", "seeding should leave zram0 unswapped"

      machine.succeed("systemctl restart systemd-zram-setup@zram0.service")
      machine.succeed("systemctl is-active systemd-zram-setup@zram0.service")

      assert "/dev/zram0 " in swaps(), "heal did not restore swap after stale-initialized device"
      log = heal_unit_journal()
      assert "stale teardown residue" in log, "heal script did not detect the stale state"
      print("heal after stale-initialized: OK")

      # --- 3. Device removed entirely (zen-kernel reset semantics) -------
      # On 7.2.9-zen a reset REMOVES the device; simulate that end state
      # directly by hot_removing it and proving the hot_add branch
      # re-creates it with the right id before the generator configures it.
      machine.succeed("swapoff /dev/zram0")
      machine.succeed("echo 0 > /sys/class/zram-control/hot_remove")
      machine.fail("test -e /sys/block/zram0")

      machine.succeed("systemctl restart systemd-zram-setup@zram0.service")
      machine.succeed("systemctl is-active systemd-zram-setup@zram0.service")

      assert "/dev/zram0 " in swaps(), "heal did not restore swap after device removal"
      log = heal_unit_journal()
      assert "re-created via zram-control/hot_add" in log, "hot_add branch did not run for removed device"
      print("heal after device removal: OK")

      # --- Guard: an in-use device must never be touched -----------------
      # Deliberately NOT a unit restart: on a healthy initialized device
      # the generator's own ExecStart would fail with EBUSY (that is why
      # nixpkgs pins restartIfChanged=false on this template). The guard
      # under test is the ExecStartPre's early exit — exercise the heal
      # script directly and assert it neither resets nor fails.
      heal_script = machine.succeed(
          "systemctl cat systemd-zram-setup@zram0.service | grep -oP '^ExecStartPre=/\\S+zram-reset-if-stale' | cut -d= -f2"
      ).strip()
      out = machine.succeed(f"{heal_script} zram0")
      assert out.strip() == "", f"in-use device was touched: {out!r}"
      assert "/dev/zram0 " in swaps(), "guard run lost swap"
      print("in-use guard: OK")
    '';
  };
}
