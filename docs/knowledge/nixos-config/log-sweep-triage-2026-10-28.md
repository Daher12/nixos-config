---
name: log-sweep-triage-2026-10-28
description: Targeted boot/runtime log sweep — 4 new issues found (Öffentlich
  mount dead, wifi wedge recurred, hyprsunset orphans, stale NM/@blank state);
  full fix plan drafted, ExitPlanMode DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_4ad2010b-f2dc-478d-9ee6-f4efb9d172b3
---

Targeted log sweep 2026-10-28 (3 read-only Explore agents, plan mode). Verified healthy: theme-switch fix LIVE (08:22 switch → lucid-auto-mode sub-second, zero warnings; final proof = 19:00 timer run); patch 128 fingerprint spam ZERO this boot; no failed units/coredumps/disks 12%. Full verbatim fix plan for all 4 items was delivered in the ExitPlanMode call (wifi-heal unit script, Öffentlich edits, ExecStartPre line, user-run cleanup commands) — denied → NOTHING EXECUTED, plan ready to re-submit.

NEW findings:
1. **P2 ~/Öffentlich never persists**: umlaut → impermanence generates `home-dk-Öffentlich.mount`, systemd rejects non-ASCII unit names ("not a valid unit name", 68×). Latent data loss, dir empty. Culprits: hosts/yoga/default.nix:408 ("Öffentlich" in persistence dirs), home.nix:267 (publicShare), home.nix:16 (xdgDirs let → GTK bookmarks). Fix: ASCII `public` + home.file "Öffentlich" symlink; rmdir both empty dirs pre-switch.
2. **P2 EC-rfkill wifi wedge RECURRED** Oct 24 22:49 (3-min outage, manual double rfkill toggle healed) → per [[lucid-wifi-129-2026-10-24]] open follow-up, auto-heal now justified. Plan: systemd.services.yoga-wifi-resume-heal (After/WantedBy suspend.target+hibernate.target, oneshot, sleep 8 → nmcli check → radio cycle → wait 40s, always exit 0, ConditionPathExists /sys/class/net/wlan0, no `${` in script = no nix escaping). Also: rfkill blocks wifi at EVERY boot since Oct 7, self-recovers 1–12s.
3. **P3 lucid hyprsunset orphans**: KillMode=process (deliberate, dock-spawn survival — keep) leaks pipe-less hyprsunset per restart (4× observed, duplicates). Fix: `ExecStartPre = "-${pkgs.procps}/bin/pkill -x hyprsunset";` (leading "-" ignores exit 1 first-start).
4. **P3 stale state (user-run sudo cmds, NOT repo config)**: (a) NM warns every boot about home-wifi/work-wifi.nmconnection — expected dangling sops symlinks in /persist/system/etc/NetworkManager/system-connections (persisted dir hosts/yoga/default.nix:358); halt+report if not dangling. (b) dead /etc/udev/rules.d/99-local.rules lives in the READ-ONLY @blank btrfs template (repo removed rule in 1e9adfc); purge = mount subvol=@blank, `btrfs property set -ts … ro false`, remount rw, rm, ro true (REQUIRED — rollback-root asserts ro=true).

Watch items (no action): single amdgpu dcn31_program_compbuf_size WARNING (escalate if recurs), ioremap firmware noise every sleep cycle, Oct 5/18 router-side wifi windows (FRITZ!Box mesh deauths, ≠ EC wedge), dbus-broker dup-name lines flood `journalctl -p 3`.

Other: nix-media unreachable — Tailscale SSH demands interactive re-auth (see [[nix-media-tailscale-ssh-access]]); BT soft-blocked (hci0+ideapad_bluetooth) though config enables it — intent unconfirmed, no change made; AskUserQuestion unanswered → proceeded with recommended defaults per [[plans-for-weaker-executor]].
