# NixOS VM test for the yoga-s2h sleep hook state machine
# (hosts/yoga/yoga-s2h.nix): the hand-rolled suspend-then-hibernate policy
# with the 2026-10-19 open-lid two-window rework.
#
# The hook's firmware-facing parts (real RTC wakes, real suspend/hibernate,
# the amdgpu abort chemistry) cannot run in QEMU — this test proves the
# DECISION LOGIC: every branch of pre/post suspend/hibernate and the recheck
# transient-unit path, driven through the real /etc hook with mount-namespace
# fakes for sysfs/procfs inputs and store-bind shims for the systemd tools
# (see tests/s2h-harness.sh). The zram interactions run against real zram
# swap, so the pre:hibernate swap-out is genuine.
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.yoga-s2h-logic
{
  testers,
  s2hModule,
  zramModule,
}:

{
  yoga-s2h-logic = testers.runNixOSTest {
    name = "yoga-s2h-logic";

    nodes.machine = {
      imports = [
        s2hModule
        zramModule
      ];

      # Real swap device for the pre:hibernate swap-out path; small so the
      # scenario swapoffs are instant.
      features.zram = {
        enable = true;
        memoryPercent = 5;
      };
    };

    testScript = ''
      start_all()

      machine.wait_for_unit("multi-user.target")
      machine.wait_until_succeeds("grep -q '^/dev/zram0 ' /proc/swaps")

      machine.copy_from_host("${./s2h-harness.sh}", "/root/s2h-harness.sh")
      machine.succeed("chmod +x /root/s2h-harness.sh")
      out = machine.succeed("/root/s2h-harness.sh 2>&1 | tee /root/harness.out")

      # Every PASS/FAIL line lands in the test log for diagnosis.
      print(out)
      summary = machine.succeed("tail -1 /root/harness.out").strip()
      assert "S2H-HARNESS: PASS=" in summary, f"harness did not finish cleanly: {summary!r}"
      assert "FAIL=0" in summary, f"s2h harness reported failures: {summary!r}"
    '';
  };
}
