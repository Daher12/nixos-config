---
name: yoga-openlid-two-window-plan-2026-10-19
description: SUPERSEDED — EXECUTED same day 2026-10-19 (QC green, STAGED, pending
  user switch), see [[yoga-hibernate-status]] for the execution record; open-lid
  idle suspend → hibernate after TWO consecutive 2h windows
metadata:
  node_type: memory
  type: project
  originSessionId: sess_735311ad-b7ba-4150-9a0e-695688d65242
---

**EXECUTED 2026-10-19 exactly per this plan** (after a second ExitPlanMode approval — the first denial was the accidental-exit glitch again): all branches, constants, resets, header comments, and REPO_OVERVIEW sync landed as specified; QC = built script drv from git index (writeShellScript shellcheck + bash -n + rendered-output inspection, no `''` artifacts) + `nixos-rebuild dry-build --flake .#yoga` green. Execution record + post-switch verification steps live in [[yoga-hibernate-status]].

Original plan (kept for the design rationale):

Plan (all in `hosts/yoga/yoga-s2h.nix` unless noted):
- New: `OPENLID_FILE=/run/yoga-s2h-openlid` counter + `MAX_OPENLID=2`.
- `post:suspend` deadline `elif lid_open` branch → 3 cases: (a) HIBERNATE_ENABLED≠1 → today's disarm+stay-awake, no marker; (b) counter ≥ 2 → rm marker, disarm, hibernate via existing `systemd-run --unit=yoga-s2h-hibernate --on-active=3s systemctl hibernate`; (c) else → write counter, disarm (keep marker), write `openlid-resuspend` to DECISION_FILE, schedule `yoga-s2h-recheck --on-active=15s` (same pattern as abort recheck) → machine awake only ~15s per cycle instead of up to 2h.
- `recheck:` gains decision `openlid-resuspend`, checked BEFORE the `lid_open → drop` guard (lid open is expected there); on AC at fire time → drop; else `systemctl suspend`.
- Counter resets (`rm -f $OPENLID_FILE`): manual-wake branch, deadline-on-AC branch, pre:suspend AC branch, post:hibernate. disarm() stays marker-agnostic. /run tmpfs = reboot resets.
- Update hook header "How this hook works" comments + REPO_OVERVIEW.md ~line 485 ("Known limits … stays awake at the deadline" sentence + "On resume:" flow).
- QC: `nix fmt hosts/yoga/yoga-s2h.nix` (explicit files!), `git add -u` (flake reads the INDEX), `nixos-rebuild dry-build --flake .#yoga`. ⚠️ yoga-s2h.nix already carries the staged uncommitted zram-race fix — NEVER git-checkout/revert the file; rollback is edit-level. HIBERNATE_ENABLED=0 still parks everything.
- Live verification (post-switch): journal grep yoga-s2h for "window 1/2 … re-suspend" then "window 2/2 … hibernating"; supervised fast test = backdate `/run/yoga-s2h-deadline` via sudo tee + hand-run hook with `SYSTEMD_SLEEP_ACTION=suspend post suspend` (really suspends/hibernates).
- Accepted edge (document in comment): the 15s recheck can suspend under a user who walks up in exactly that window — self-healing, one keypress wakes; manual wake resets everything.
- After execution: update [[yoga-hibernate-status]] ("lid-open-at-deadline by design" becomes stale).

Key facts established while planning: idle suspend = hypridle.conf 7200s listener → plain `systemctl suspend`; hook is trigger-agnostic, discriminates only lid/AC at deadline; today's lid-open deadline behavior wastes battery (awake up to 2h until hypridle re-suspends, ~10 min screen-on via after_sleep_cmd dpms-on + 600s dpms listener); logind refuses in-hook sleep requests → all deferred actions ride systemd-run transient units.
