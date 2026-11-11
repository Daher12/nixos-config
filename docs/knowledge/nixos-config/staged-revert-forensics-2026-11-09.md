---
name: staged-revert-forensics-2026-11-09
description: User reported "reboot reverted my changes" — forensics 2026-11-09
  proved NO reboot happened (btime Nov 7 14:04); reversion = Nov 8 01:32
  noctalia state-strip while the compensating switch (gen 202, 01:09) predated
  the noctalia.nix edits (01:30); verdict = ONE rebuild switch restores all,
  nothing to re-apply. PLAN ready, ExitPlanMode DENIED.
metadata:
  node_type: memory
  type: project
  originSessionId: session_9c4970b8204a36269faa2223d45b9a43
---

PLAN ONLY (ExitPlanMode DENIED 2026-11-09; recovery plan delivered in chat). User: "rebooting reverted some of the changes… to niri especially — can I just rebuild switch or re-apply everything?"

**Verdict: one `sudo nixos-rebuild switch --flake .#yoga-niri` (NOT `nus` — it would drag flake.lock updates into the recovery) restores everything. All "lost" work is intact in the git index.**

**What actually happened (user's reboot theory WRONG):** kernel btime = 2026-11-07 14:03:57 CET (matches who -b; ~2.4d uptime) — no reboot since. The reversion hit at **Nov 8 01:32** when the harvest session stripped `~/.local/state/noctalia/settings.toml` (which carried bar geometry/theme/login-box/energy as live-only state) and restarted the shell; the harvested `home/noctalia.nix` edit landed **01:30, AFTER the last switch at 01:09 (gen 202)** — see [[noctalia-config-export-energy-2026-11-08]]. So the shell restarted onto the OLD config with the state layer gone.

**Deployed vs missing (verified against live store paths):**
- ALREADY LIVE (gen 202, Nov 8 01:09): foot swap (Mod+T footclient, `^(foot|footclient)$` rules, kitty config gone), zcode-unmax `setsid --fork` fix, xcursor 32, lang=de, dock off, lockscreen round-3.
- STAGED-ONLY (switch will newly deploy): home/noctalia.nix 01:30 (full GUI harvest + energy timeline + hooks + kbd script), hosts/yoga/{default,home}.nix 01:25 (greeter /var/lib persist + dms persistence drop).
- Live noctalia config.toml = HEAD values (screen-off 180 / lock 300 no grace / suspend 900 plain, no hooks) — the "niri" feel the user noticed.
- Safety net: `~/.local/state/noctalia/settings.toml.bak-2026-11-08` (4421 bytes, has the old live drift incl. kbdtest/lock180/screen185/suspend2400).

**Plan:** test-suite fast yoga-niri → user runs the sudo switch → agent post-switch: grep config.toml for grace/hooks/fade/thickness-28/Alt theme, `noctalia msg config-get idle.behavior.suspend.timeout` (1500 / 5400 AC), `niri msg action load-config-file`, restart foot-server, `rm -rf ~/.cache/kitty`, live checklist (kbd off 60s, lock 5:00+grace, screen-off 5:30, zcode launcher survives 30s+ — fix deployed but NEVER live-verified). Commit only on explicit ask. Rollback: `--rollback` → gen 202.

**Lore (forensics technique):**
- `/proc/stat` `btime` = kernel boot time, namespace-proof — definitive against a possibly-stale sandbox `/run/utmp` (who -b). Plan-mode sandbox blocked even read-only Bash AND SendMessage to subagents; main-agent Read tool still reads /nix/store + /proc fine — delegate shell fact-gathering to an Explore agent (its read-only Bash works).
- Generation timeline via `/nix/var/nix/profiles/system-N-link` mtimes (nix-env --list-generations needs root — permission denied); `/run/booted-system` vs `/run/current-system` divergence = switched-without-reboot (booted 194, current 202 — normal, harmless).
- Integrated HM has no per-user profile dir — HM generation rides the system generation; compare live ~/.config symlinks' store targets against `git show :file` staged content to determine exactly what a pending switch will change.
- File mtimes vs switch time: staged .nix mtimes (01:25/01:30) after the last profile link (01:09) = those edits never deployed; flake builds from the INDEX so the staged bundle is exactly what the next switch ships.
- The stripped state file re-materializes benignly; reversion blame goes to strip+restart, not the (nonexistent) reboot — cf. [[ask-dont-infer-system-state]].

Related: [[noctalia-config-export-energy-2026-11-08]], [[zcode-launcher-crash-bwrap-pdeathsig-2026-11-07]], [[shell-strategy-converge-niri-noctalia-2026-11-07]], [[zcode-shell-sandbox-etc]]
