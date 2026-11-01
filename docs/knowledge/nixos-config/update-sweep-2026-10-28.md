---
name: update-sweep-2026-10-28
description: Executed update sweep — all pins incl. lucid (quickshell at tip, no
  release in sight → rule said bump lucid); opencode v2.2.0, mikromcp 1.16.0,
  lucid 4b8fc9a with 116+125 re-expressed, .orig postPatch sweep
metadata:
  node_type: memory
  type: project
  originSessionId: sess_3bff24fb-b64d-40fe-acd2-a0b246ed7e0b
---

Update sweep 2026-10-28: EXECUTED + QC green, STAGED, no commit/switch (house rules). Rollback snapshot: /tmp/flake.lock.pre-20261027. Triage trees in /tmp/lucid-update-dk/ (upstream @4b8fc9a, cumulative work tree complete).

Bumped: nixpkgs da6dc0e→718f670e (nixos-26.05 — NOT unstable, repo tracks stable), nixos-hardware→8ba09466, home-manager→24f21905, sops-nix→60182817, dank-greeter→0f5de05 (+ qml-common 08efce90), spotx-nix→54f055d (spotx-bash d145b19), **opencode v2.1.4→v2.2.0** (released 10-27; gate build of upstream flake clean BEFORE tag edit — new standing rule per bump; nixpkgs_2 unchanged 3181085 = upstream's own pin), **mikromcp 1.14.1→1.16.0** (repo stopped tagging at v1.9.0 — lockfile vendored from npm gitHead 957f8b3 via raw.githubusercontent; hashes src 3PNzib7…, npmDeps O+aexH…), **lucid 8bc32666→4b8fc9a** (57 commits, runbook Scenario A).

LUCID round details:
- Quickshell decision input: pin 9b0f339 == upstream master tip, v0.3.2 (10-08) still newest release, no release-prep commits, PR #1049 disk-cache still open → user's rule ("no quickshell update in sight → bump lucid") fired.
- Patches: 17/19 applied clean, **116 + 125 re-expressed**. 116: upstream turned date LTexts into bold day+date Rows (dayText/dayDateText, new lookPref/root.look) — same 3 flips on the Rows. 125: upstream added audioCombine/Audio.sink eager touch — kept eager, same 11 singletons deferred. No drops, no new patches (layer stays 19 — the runbook's old "EIGHTEEN" was a pre-existing miscount, fixed 2026-10-28).
- **lucidPatched postPatch now deletes *.orig**: GNU patch drops .orig backups on fuzz/offset hunks; they rode rsync into the live tree (Notifs.qml.orig sat deployed a whole generation; LockMedia/LockSurface.qml.orig appeared in this build). rsync --delete self-heals the live tree at next switch.
- **Self-updater policy** (upstream lucidupdate/, landed 10-20): hourly version probe + Settings→About "Update" button running install.sh with sudo — left in code deliberately (manual confirm + password to trigger; HM rsync re-converges any damage), documented never-click in runbook §5 + P7. Re-decide if notification nags.
- stateFiles gate did NOT trip. Fuzz hunks: 113 LockMedia, 122 Prefs+widgets (offsets up to 76 lines from start-button/look-anim churn — markers all pass).
- Appendix A: 78 greps pass; 6 "fails" were a STALE expectation (bare lucidlock/*.qml glob matches 5 files 113 never touched + new LockLive) — table row fixed to enumerate the 8 real files.
- New upstream surfaces: start button module, bar look-switch animations, Chip/Accent looks REMOVED upstream, media vinyl/mini panels, lucidnews/lucidosl dirs ride rsync.

QC green: nix flake check ×2 (incl. final staged state), dry-builds yoga/latitude/nix-media, host-units-smoke VM test, attribution diff (52 files, all map to patches, 0 .orig), opencode+quickshell wrapper in yoga closure, mikromcp builds + reports 1.16.0. /tmp 2GB gotcha re-hit: upstream wallpapers dir ~fills tmpfs with 3+ triage copies — rm wallpapers from work trees.

Pending: user switch yoga → `systemctl --user restart lucid` (mandatory) → smoke per runbook P7 (bar, launcher, lock German + no fingerprint spam, wifi panel, Start button, Settings→About untouched, greeter next boot, opencode v2.2.0 launch, Spotify, mikromcp) → latitude + nix-media switches → sops rekey not needed → commit when user says.
