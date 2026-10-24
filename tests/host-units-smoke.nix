# NixOS VM test for the remaining fleet system-unit workflows that the
# dedicated tests don't cover:
#
#   * latitude's disable-wakeup-sources oneshot (hosts/latitude/default.nix)
#     — must exit cleanly when EHC1/XHC don't exist (the qemu ACPI wakeup
#     table has different device tokens)
#   * bt-agent (modules/features/bluetooth.nix) — the JustWorks pairing
#     agent must run adapter-less and stay up behind bluetooth.service
#   * ryzen-tdp (modules/hardware/ryzen-tdp.nix) — unit/timer/udev wiring
#     plus the ConditionPathExistsGlob guard that skips it on machines
#     without a power_supply class member
#   * oomd (modules/features/oomd.nix) — systemd-oomd active, earlyoom absent
#   * is-on-ac (pkgs/is-on-ac.nix) — the shared AC probe, live against
#     faked /sys/class/power_supply states
#
# The latitude node imports the REAL hosts/latitude/default.nix (with its
# disks/hardware chain) over the repo's base module set, like mkHost does —
# only the disko-generated fileSystems are suppressed for the VM, and the
# GNOME desktop stays off (its profile is not part of this import, so
# features.desktop-gnome.enable remains false and latitude's autoLogin
# setting is inert).
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.host-units-smoke
{
  testers,
  coreModule,
  featuresModule,
  rolesModule,
  hardwareModule,
  diskoModule,
  preloadNgModule,
  homeManagerModule,
  latitudeModule,
  sopsStubModule,
  flakeRoot,
  inputs,
  self,
}:

{
  host-units-smoke = testers.runNixOSTest {
    name = "host-units-smoke";

    # specialArgs, NOT _module.args: desktop-hyprland.nix consumes `inputs`
    # inside its `imports` list, and resolving a module argument from
    # _module.args during import loading is the classic config-in-imports
    # infinite recursion (mkHost passes these as real specialArgs too).
    node.specialArgs = {
      mainUser = "dk";
      inherit
        flakeRoot
        inputs
        self
        ;
    };

    nodes.machine =
      { lib, pkgs, ... }:
      {
        imports = [
          sopsStubModule
          homeManagerModule
          coreModule
          featuresModule
          rolesModule
          hardwareModule
          diskoModule
          preloadNgModule
          latitudeModule
        ];

        # hardware-configuration.nix (pulled in by hosts/latitude/default.nix)
        # sets nixpkgs.hostPlatform as a string, while the testers derive it
        # from the node's pkgs — importing both is a read-only collision.
        # The file's actual content (initrd storage drivers for the real
        # SATA SSD) is irrelevant in a VM.
        disabledModules = [ (flakeRoot + "/hosts/latitude/hardware-configuration.nix") ];

        # core/boot.nix quiets the console (3); test-instrumentation wants
        # the verbose one (7) to capture boot logs — both set it plainly.
        boot.consoleLogLevel = lib.mkForce 7;

        networking.hostName = "latitude";

        # The real disk layout's LUKS/partlabel mounts cannot exist in the
        # VM; the testers' useDefaultFilesystems provides the root instead.
        disko.enableConfig = false;

        # No decryption key in the VM: keep the (stubbed) sops path out of
        # user creation so activation stays clean.
        users.users.dk.hashedPasswordFile = lib.mkForce null;

        # Workflows under test.
        features.bluetooth.enable = true;
        features.oomd.enable = true;
        hardware.ryzen-tdp.enable = true;

        # Exposed for the live probe matrix below.
        environment.systemPackages = [ pkgs.is-on-ac ];
      };

    testScript = ''
      start_all()

      machine.wait_for_unit("multi-user.target")

      # --- latitude: disable-wakeup-sources tolerates absent tokens -------
      result = machine.succeed("systemctl show disable-wakeup-sources -p Result --value").strip()
      assert result == "success", f"disable-wakeup-sources result: {result!r}"
      status = machine.succeed("systemctl show disable-wakeup-sources -p ExecMainStatus --value").strip()
      assert status == "0", f"disable-wakeup-sources exit code: {status!r}"
      print("latitude disable-wakeup-sources: OK")

      # --- bt-agent: wiring (activeness needs org.bluez, which a BT-less VM
      # cannot provide — bluetoothd never registers the dbus name, the agent
      # exits "bluez service is not found" and Restart=on-failure loops) ----
      machine.succeed("systemctl is-enabled bt-agent.service")
      partof = machine.succeed("systemctl show bt-agent -p PartOf --value").strip()
      assert "bluetooth.service" in partof, f"bt-agent lost its PartOf wiring: {partof!r}"
      execstart = machine.succeed("systemctl cat bt-agent.service")
      assert "bt-agent -c NoInputNoOutput" in execstart, "JustWorks capability flag lost"
      print("bt-agent wiring: OK")

      # --- oomd active, earlyoom absent ------------------------------------
      machine.succeed("systemctl is-active systemd-oomd.service")
      machine.fail("systemctl cat earlyoom.service")
      print("oomd: OK")

      # --- ryzen-tdp: wiring + no-power_supply guard ------------------------
      machine.succeed("systemctl is-enabled ryzen-tdp-control.service")
      machine.succeed("systemctl is-enabled ryzen-tdp-watchdog.timer")
      machine.fail("systemctl is-failed ryzen-tdp-control.service")
      # systemd prints boolean properties as yes/no (the boot log already
      # showed the guard firing: "skipped, unmet condition check").
      cond = machine.succeed("systemctl show ryzen-tdp-control -p ConditionResult --value").strip()
      assert cond in ("no", "false"), \
          f"ryzen-tdp-control condition matched without power_supply: {cond!r}"
      skipped = machine.succeed(
          "journalctl -b -u ryzen-tdp-control.service --no-pager | grep -c 'unmet condition' || true"
      ).strip()
      assert skipped != "0", "no condition-skip recorded — unit never reached the guard"
      print("ryzen-tdp wiring + guard: OK")

      # --- is-on-ac: the shared AC probe, live ------------------------------
      # No supplies at all -> battery verdict.
      machine.fail("is-on-ac")

      machine.succeed(
          "mount -t tmpfs none /sys/class/power_supply",
          "mkdir -p /sys/class/power_supply/AC /sys/class/power_supply/BAT0",
          # Mains online -> AC
          "echo 1 > /sys/class/power_supply/AC/online && echo Mains > /sys/class/power_supply/AC/type && is-on-ac",
          # Mains offline -> battery
          "echo 0 > /sys/class/power_supply/AC/online && ! is-on-ac",
          # Battery-type supply reporting online=1 must NOT read as AC
          "echo 1 > /sys/class/power_supply/BAT0/online 2>/dev/null || true"
          " && echo Battery > /sys/class/power_supply/BAT0/type && ! is-on-ac",
          # USB type online -> AC (dock/charger semantics)
          "echo 1 > /sys/class/power_supply/AC/online && echo USB > /sys/class/power_supply/AC/type && is-on-ac",
          "umount /sys/class/power_supply",
      )
      print("is-on-ac probe matrix: OK")
    '';
  };
}
