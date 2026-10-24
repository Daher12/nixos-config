# NixOS VM test for the nix-media update pipeline
# (hosts/nix-media/maintenance.nix + ntfy.nix + docker.nix):
#
#   git pull (ExecStartPre, as the user) → nixos-upgrade stages a boot
#   generation → weekly-reboot reboots into it only when idle (five guards)
#   → failures surface via the ntfy-failure@ OnFailure bridge.
#
# The expensive/un simulable edges are stubbed, everything repo-owned runs
# for real:
#   * nixos-rebuild: upstream auto-upgrade invokes it via the absolute path
#     config.system.build.nixos-rebuild, so the test swaps that option for a
#     shim (no real in-VM rebuild, no network fetch). The git pull before it
#     is the REAL ExecStartPre from maintenance.nix against a local bare
#     origin — user ownership, --ff-only and runuser euid all exercised.
#   * weekly-reboot branches run the REAL unit script directly with a
#     controlled PATH (shutdown + systemctl shims) and, where needed,
#     mount-namespace fakes for /proc/loadavg and /proc/uptime.
#   * sops is stubbed at option level (path shape only): ntfy-send's
#     missing-secret skip branch is itself production behavior we want
#     proven, and no real notification may ever leave this test.
#   * container images are never pulled (autoStart off, refresh timer only
#     inspected) — docker-network-jellyfin DOES run against the real daemon.
#
# Run explicitly (NOT part of `checks` — keeps `nix flake check`/CI fast):
#   nix build .#nixosTests.x86_64-linux.nix-media-upgrade-pipeline
{
  testers,
  pkgs,
  mediaRoleModule,
  maintenanceModule,
  ntfyModule,
  dockerModule,
  sopsStubModule,
}:

let
  # Stand-in for nixos-rebuild: records its argv and optionally "stages" a
  # boot generation (points the system profile at a fake generation dir, as
  # the real rebuild's `boot` operation would) or fails on demand.
  fakeRebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
    echo "fake-nixos-rebuild $*" >> /run/upgrade-test/rebuild-calls
    mkdir -p /run/upgrade-test/fake-gen
    ln -sfn /run/upgrade-test/fake-gen /nix/var/nix/profiles/system 2>/dev/null || true
    exit "$(cat /run/upgrade-test/rebuild-result 2>/dev/null || echo 0)"
  '';
in
{
  nix-media-upgrade-pipeline = testers.runNixOSTest {
    name = "nix-media-upgrade-pipeline";

    nodes.server =
      { lib, pkgs, ... }:
      {
        _module.args.mainUser = "dk";
        imports = [
          sopsStubModule
          mediaRoleModule
          maintenanceModule
          ntfyModule
          dockerModule
        ];

        roles.media.enable = true;
        time.timeZone = "UTC";

        users.users.dk = {
          isNormalUser = true;
          extraGroups = [ "docker" ];
        };

        # Upstream calls this by absolute path — swap it, not PATH.
        system.build.nixos-rebuild = lib.mkForce fakeRebuild;

        # Keep GB-sized image pulls out of the test: containers never start;
        # the network-ensure unit and the refresh WIRING are still asserted.
        virtualisation.oci-containers.containers =
          lib.genAttrs
            [
              "jellyfin"
              "audiobookshelf"
              "cadvisor"
            ]
            (_: {
              autoStart = lib.mkForce false;
            });

        # qemu disks have no SMART data; smartd would just poll nothing.
        services.smartd.enable = lib.mkForce false;

        # The unit scripts inspect/record via /run/upgrade-test.
        systemd.tmpfiles.rules = [ "d /run/upgrade-test 0755 root root - -" ];

        environment.systemPackages = [ pkgs.git ];
      };

    testScript = ''
      start_all()

      server.wait_for_unit("multi-user.target")
      server.wait_for_unit("docker.service")

      # --- static wiring ------------------------------------------------
      unit = server.succeed("systemctl cat nixos-upgrade.service")
      assert "runuser -u dk --" in unit and "git -C /home/dk/nixos-config pull --ff-only" in unit, \
          "git-pull ExecStartPre not wired"
      on_failure = server.succeed("systemctl show nixos-upgrade -p OnFailure --value").strip()
      # %n already includes the .service suffix; the template itself must
      # NOT add another (used to instantiate ….service.service).
      assert on_failure == "ntfy-failure@nixos-upgrade.service", \
          f"OnFailure mis-wired: {on_failure!r}"
      # The container auto-update path is alert-wired too.
      refresh_on_failure = server.succeed(
          "systemctl show docker-image-refresh -p OnFailure --value"
      ).strip()
      assert refresh_on_failure == "ntfy-failure@docker-image-refresh.service", \
          f"docker-image-refresh OnFailure mis-wired: {refresh_on_failure!r}"
      # Dead-man's switch: daily heartbeat timer exists.
      heartbeat_timer = server.succeed("systemctl cat ntfy-heartbeat.timer")
      assert "OnCalendar=daily" in heartbeat_timer, "heartbeat timer calendar wrong"

      # The upgrade-failed guard lives in the generated script, not the
      # unit file — systemctl show prints ExecStart as "{ path=...; ... }".
      reboot_script = server.succeed(
          "systemctl show weekly-reboot.service -p ExecStart --value"
          " | grep -oP 'path=\\K[^ ;]+' | head -1"
      ).strip()
      reboot_body = server.succeed(f"cat {reboot_script}")
      assert "nixos-upgrade.service" in reboot_body, "upgrade-failed guard missing"
      # is-failed alone misses Restart=on-failure limbo — the guard must
      # probe Result AND ActiveState (the W2/W2b branches below prove the
      # semantics against shims).
      assert "-p Result" in reboot_body and "-p ActiveState" in reboot_body, \
          "weekly-reboot guard does not probe Result/ActiveState"

      # Same story as weekly-reboot: the pull list lives in the generated
      # ExecStart script, not the unit file.
      refresh_script = server.succeed(
          "systemctl show docker-image-refresh.service -p ExecStart --value"
          " | grep -oP 'path=\\K[^ ;]+' | head -1"
      ).strip()
      refresh = server.succeed(f"cat {refresh_script}")
      for image in ["lscr.io/linuxserver/jellyfin", "ghcr.io/advplyr/audiobookshelf", "gcr.io/cadvisor/cadvisor"]:
          assert image in refresh, f"{image} missing from refresh unit"

      # OnCalendar/Persistent are unit-file settings, not bus properties —
      # `systemctl show -p` returns empty for them; read the unit instead.
      reboot_timer = server.succeed("systemctl cat weekly-reboot.timer")
      assert "OnCalendar=Sun 07:30" in reboot_timer, "weekly-reboot calendar wrong"
      # NixOS serializes timerConfig booleans as true/false; systemd's own
      # canonical form is yes/no — accept either.
      assert "Persistent=true" in reboot_timer or "Persistent=yes" in reboot_timer, \
          "weekly-reboot not Persistent"
      upgrade_timer = server.succeed("systemctl cat nixos-upgrade.timer")
      assert "05:00" in upgrade_timer, "upgrade timer calendar wrong"

      # --- docker: the network-ensure oneshot against the real daemon ---
      server.succeed("systemctl start docker-network-jellyfin.service")
      server.succeed("docker network inspect jellyfin")
      print("docker network ensure: OK")

      # --- upgrade pipeline: pull as dk, then "stage" --------------------
      # Local bare origin seeded one commit ahead of the clone, so the
      # ExecStartPre pull has real work to do.
      server.succeed(
          "git init --bare -b main /srv/origin.git",
          "git -c user.email=t@test -c user.name=t clone /srv/origin.git /home/dk/nixos-config",
          "cd /home/dk/nixos-config && git checkout -B main -q"
          " && git -c user.email=t@test -c user.name=t commit --allow-empty -m initial -q && git push -q origin main",
          "git -c user.email=t@test -c user.name=t clone -q /srv/origin.git /tmp/seed && cd /tmp/seed"
          " && git -c user.email=t@test -c user.name=t commit --allow-empty -m 'fleet update' -q && git push -q origin main",
          "chown -R dk:users /home/dk/nixos-config",
      )
      head_before = server.succeed("git -c safe.directory=/home/dk/nixos-config -C /home/dk/nixos-config rev-parse HEAD").strip()

      server.succeed("rm -f /run/upgrade-test/rebuild-calls")
      server.succeed("systemctl start nixos-upgrade.service")
      # A finished oneshot is "inactive", not "active" — wait for the job
      # to leave "activating", then judge it by its Result.
      server.wait_until_succeeds(
          "test \"$(systemctl show nixos-upgrade -p ActiveState --value)\" != activating"
      )
      result = server.succeed("systemctl show nixos-upgrade -p Result --value").strip()
      assert result == "success", f"nixos-upgrade did not succeed: {result!r}"

      head_after = server.succeed("git -c safe.directory=/home/dk/nixos-config -C /home/dk/nixos-config rev-parse HEAD").strip()
      assert head_before != head_after, "git pull did not advance the clone"
      pulls = server.succeed("git -c safe.directory=/home/dk/nixos-config -C /home/dk/nixos-config log --oneline -2")
      assert "fleet update" in pulls, "expected commit not pulled"

      calls = server.succeed("cat /run/upgrade-test/rebuild-calls")
      assert "boot" in calls and "--flake path:/home/dk/nixos-config#nix-media" in calls, \
          f"rebuild shim saw wrong argv: {calls!r}"
      staged = server.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      current = server.succeed("readlink -f /run/current-system").strip()
      assert staged != current, "no staged generation after upgrade"
      print("upgrade pipeline: pull + stage OK")

      # --- weekly-reboot guard matrix (real script, controlled PATH) -----
      # Reuse the script resolved above via reboot_script.

      server.succeed("mkdir -p /root/wr-shims")
      # systemctl shim: answers the two probes the guard makes.
      #   upgrade-failed  → Result=exit-code            (abort)
      #   upgrade-running → Result=success, ActiveState=activating (abort)
      #   default         → Result=success, ActiveState=inactive  (pass)
      server.succeed("cat > /root/wr-shims/systemctl <<'EOF'\n"
          "#!/usr/bin/env bash\n"
          # NB: keep single-quote PAIRS out of this shim — testScript is a
          # Nix indented string, and two adjacent single quotes would
          # terminate it (that is why the shims avoid empty-string inits).
          "if [ \"$1\" = show ]; then\n"
          "  prop=\"\"; prev=\"\"\n"
          "  for a in \"$@\"; do [ \"$prev\" = -p ] && prop=\"$a\"; prev=\"$a\"; done\n"
          "  if [ -f /root/wr-shims/upgrade-failed ]; then\n"
          "    [ \"$prop\" = Result ] && echo exit-code\n"
          "  elif [ -f /root/wr-shims/upgrade-running ]; then\n"
          "    [ \"$prop\" = Result ] && echo success\n"
          "    [ \"$prop\" = ActiveState ] && echo activating\n"
          "  else\n"
          "    [ \"$prop\" = Result ] && echo success\n"
          "    [ \"$prop\" = ActiveState ] && echo inactive\n"
          "  fi\n"
          "fi\n"
          "exit 0\n"
          "EOF\n"
          "cat > /root/wr-shims/shutdown <<'EOF'\n"
          "#!/usr/bin/env bash\n"
          "echo \"shutdown $*\" >> /run/upgrade-test/shutdown-canary\n"
          "EOF\n"
          "chmod +x /root/wr-shims/systemctl /root/wr-shims/shutdown")

      def run_reboot_branch(name, extra_env="", fake_load=None, fake_uptime=None):
          pre = ""
          if fake_load is not None:
              pre += f"printf '{fake_load}\\n' > /root/wr-shims/loadavg && "
          if fake_uptime is not None:
              pre += f"printf '{fake_uptime}\\n' > /root/wr-shims/uptime && "
          ns = ""
          if fake_load is not None:
              ns += "mount --bind /root/wr-shims/loadavg /proc/loadavg && "
          if fake_uptime is not None:
              ns += "mount --bind /root/wr-shims/uptime /proc/uptime && "
          cmd = (
              f"{pre}unshare --mount --propagation private bash -c '{ns}"
              f"PATH=/root/wr-shims:/run/current-system/sw/bin {extra_env} {reboot_script}' 2>&1"
          )
          # execute, not succeed: several branches exit non-zero BY DESIGN
          # (W2 aborts with exit 1); the output text is what we assert on.
          _, out = server.execute(cmd)
          return out

      # W1: profiles identical (pristine state, upgrade not yet staged)
      server.succeed(f"ln -sfn {current} /nix/var/nix/profiles/system")
      out = run_reboot_branch("W1")
      assert "Already on latest generation" in out, f"W1: {out!r}"

      # restore the staged generation for the remaining branches
      server.succeed("ln -sfn /run/upgrade-test/fake-gen /nix/var/nix/profiles/system")

      server.succeed("touch /root/wr-shims/upgrade-failed")
      out = run_reboot_branch("W2")
      assert "Last upgrade failed" in out, f"W2: {out!r}"
      server.succeed("rm /root/wr-shims/upgrade-failed")

      # W2b: upgrade retry mid-build (Result clean, but the unit is still
      # activating — an hourly restart can be running at Sun 07:30; a
      # reboot then would kill the build).
      server.succeed("touch /root/wr-shims/upgrade-running")
      out = run_reboot_branch("W2b")
      assert "Last upgrade failed" in out, f"W2b: {out!r}"
      server.succeed("rm /root/wr-shims/upgrade-running")

      # W3: transcode guard — a process literally comm=ffmpeg. Three traps:
      # coreutils is multi-call (a copied binary rejects argv0 "ffmpeg"),
      # bash tail-execs the last command (comm reverts to "sleep" — hence
      # the trailing `true`), echo's trailing newline lands IN comm and
      # breaks pgrep -x (hence printf), and the console reaps its command's
      # process group (hence setsid).
      server.succeed(
          "setsid bash -c 'printf ffmpeg > /proc/self/comm; sleep 120; true'"
          " >/dev/null 2>&1 </dev/null & sleep 0.5; pgrep -x ffmpeg"
      )
      out = run_reboot_branch("W3")
      assert "Transcoding active" in out, f"W3: {out!r}"
      server.succeed("pkill -x ffmpeg || true")

      out = run_reboot_branch("W4", fake_load="7.00 7.00 7.00 1/500 9000")
      assert "High load: 7 - skipping reboot" in out, f"W4: {out!r}"

      # The docker-enabled VM idles above load 2, so every branch that must
      # REACH the uptime guard needs a calm fake loadavg too.
      out = run_reboot_branch(
          "W5",
          fake_load="0.10 0.20 0.30 1/500 9000",
          fake_uptime="100.52 300.10",
      )
      assert "System recently booted" in out, f"W5: {out!r}"

      server.succeed("rm -f /run/upgrade-test/shutdown-canary")
      out = run_reboot_branch("W6", fake_load="0.10 0.20 0.30 1/500 9000", fake_uptime="40000.00 80000.00")
      assert "Applying staged update" in out, f"W6: {out!r}"
      canary = server.succeed("cat /run/upgrade-test/shutdown-canary")
      assert "-r +1" in canary, f"W6 shutdown not scheduled: {canary!r}"
      print("weekly-reboot guard matrix: OK")

      # Unit-level sanity: the real unit on pristine (equal) state exits 0.
      server.succeed("ln -sfn $(readlink -f /run/current-system) /nix/var/nix/profiles/system")
      server.succeed("systemctl start weekly-reboot.service")
      journal = server.succeed("journalctl -b -u weekly-reboot.service --no-pager | tail -5")
      assert "Already on latest generation" in journal
      print("weekly-reboot unit-level: OK")

      # --- ntfy OnFailure bridge, end to end ----------------------------
      # ntfy-boot already logged one skip line at boot, so count lines and
      # require the bridge to ADD one (the failure path's own send).
      before = int(server.succeed(
          "journalctl -t ntfy-send --no-pager | grep -c 'Skipping notification' || true"
      ).strip() or 0)

      server.succeed("echo 1 > /run/upgrade-test/rebuild-result")
      server.succeed("systemctl restart nixos-upgrade.service || true")
      server.wait_until_fails("systemctl is-active nixos-upgrade.service")
      # Restart=on-failure (1h) means the unit sits in auto-restart limbo
      # rather than the "failed" state — the last Result is the truth
      # ("exit-code" is Result's vocabulary for a failing process).
      result = server.succeed("systemctl show nixos-upgrade -p Result --value").strip()
      assert result == "exit-code", f"upgrade unit did not fail: {result!r}"

      # 60s settle delay is part of the production design (rebuild-restart
      # races); wait for the bridge to conclude in its skip branch.
      import time
      bridge = ""
      for _ in range(30):
          bridge = server.succeed("journalctl -t ntfy-send --no-pager | tail -3")
          after = int(server.succeed(
              "journalctl -t ntfy-send --no-pager | grep -c 'Skipping notification' || true"
          ).strip() or 0)
          if after > before:
              break
          time.sleep(5)
      assert after > before, \
          f"ntfy bridge did not run (secret-absent branch): {bridge!r}"
      print("ntfy OnFailure bridge: OK")
    '';
  };
}
