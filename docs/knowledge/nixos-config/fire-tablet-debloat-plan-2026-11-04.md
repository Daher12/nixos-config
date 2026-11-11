---
name: fire-tablet-debloat-plan-2026-11-04
description: Fire HD 10 2023 + HD 8 2020 debloat PLAN (ExitPlanMode denied, NOTHING executed) — Lawnchair launcher, no Google, standalone repo ~/Projects/fire-debloat, curated lists (Fire-Tools stock list UNSAFE: removes parentalcontrols/tahoe/pm/dcp)
metadata:
  type: project
---

Plan-mode session 2026-11-04 (plan delivered via ExitPlanMode → permission denied, nothing executed). Extends [[tv-firetablet-debloat-research-2026-10-28]].

**User decisions (locked):** Lawnchair launcher on parent profile (Nova dev wound-down); NO Google Play (Appstore + Aurora Store/sideload); deliverables in standalone dir `~/Projects/fire-debloat/` (new git repo, exists-empty); kids profile (Amazon Kids/tahoe) untouched. Skipped-question default applied: Prime Video, Alexa, Music, Photos all REMOVED (one-line list edit to keep any).

**Key research corrections vs the 10-28 memo:**
- Fire-Tools' stock `Debloat.txt` removes `com.amazon.parentalcontrols`, `com.amazon.pm` (parental monitoring), `com.amazon.tahoe`, `com.amazon.cloud9.kids`, `com.amazon.comms.kids` and the whole `dcp` account framework → NEVER run as-is with kids profiles. Build own curated lists (informed by Fire-Tools list + oximenvn gist/avoidik comment + Chris Titus). Method: Fire-Tools uses `pm disable-user` + `pm clear`; our plan uses `pm uninstall -k --user 0` (undo via `cmd package install-existing --user 0`).
- Launcher on Fire OS 8.3 (HD 10 2023): NOT proven broken — Fire-Tools v2.0 order (install launcher BEFORE disabling firelauncher) fixed black-screen; Oct-2025 guides confirm OTA can no longer be blocked at all. Plan = per-device verify-and-rollback tree: HD 8 2020 (Fire OS 7.3) classic uninstall-firelauncher; HD 10 2023 LauncherHijack V403 accessibility route first, rollback ladder always.
- Keep-guard additions beyond memo: `com.amazon.zico` (child-profile framework per r/kindlefire), `kindle.rdmdeviceadmin` (remote parental mgmt), `kindle.personal_video` (only local video player w/o Play), TTS/accessibility (svox.pico, ivona, logan — kids read-aloud), cloud9.contentservice/systembrowserprovider (Silk = only browser).
- Optional tier (`--aggressive` only): identity.auth/imp, device.sync family, tcomm family, kindle.cms, dreams.basic.

**Phase 0 — device prep order (locked 2026-11-09 after user asked how to proceed):** per tablet, BEFORE any debloat: (1) OOBE Wi-Fi + main-account login; (2) update to final firmware FIRST while stock (OTA restores removed apps → debloat once, not twice); (3) parental controls + PIN + child profile + kids app/content grants while stock (baseline then includes child user; kids-verification step needs a profile to test); (4) USB to yoga → Phase B. Note: enabling ADB in Developer Options prompts for the parental PIN while controls are on — normal, not a blocker.

**Planned deliverable:** `fire-debloat.sh` (subcommands discover/apply/undo/launcher/status, `--device hd8|hd10`, guard-list hard-abort, all cmds pinned `--user 0`) + packages/{keep-guard,remove-common,remove-hd8,remove-hd10,remove-optional}.txt + RUNBOOK.md + state/ logs. Phase A author repo (no devices), Phase B run per device (yoga host, adb via nix-shell -p android-tools, udev+adbusers already configured).

**Why:** user asked to plan full debloat of both tablets incl. kids profile protection + parent-profile launcher swap.
**How to apply:** if user resumes this work, the full plan text was delivered in-session 2026-11-04; execute Phase A from it, `discover` fills per-device tier-2 lists at first USB contact. After execution write the EXECUTED record and supersede this file.
