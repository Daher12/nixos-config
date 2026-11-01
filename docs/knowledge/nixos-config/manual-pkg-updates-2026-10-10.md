---
name: manual-pkg-updates-2026-10-10
description: Manual-pin update round EXECUTED — quickshell 0.3.2, opencode
  v2.0.26, mikromcp 1.13.1, zcode 3.14.5 (old pin purged from CDN!), lanzaboote
  v1.2.0; lucid v1.20 already HEAD; all QC green, STAGED uncommitted
metadata:
  node_type: memory
  type: project
  originSessionId: sess_d75e80c4-aa49-47c2-a733-c582b290ab9c
---

Manual-pin update round 2026-10-10, EXECUTED + QC green, **STAGED only (never committed) on top of the German round-2 index + parallel-session patch 120-smooth-caret**:

- **quickshell 0.3.1→0.3.2** (`4f508be5…`): compare 5d5d498→v0.3.2 = 3 commits, only NM "prefer AP security" + docs + version — `src/core/iconimageprovider.cpp` UNTOUCHED → patch 201 kept as-is (race NOT fixed upstream), replicated wrapper unchanged (upstream default.nix delta = version string only). Built fresh, `qs --version` = 0.3.2, qt5compat strings-check hits. `minQuickshell` stays "0.3.1" — raise only after user smoke test (runbook §3 rule).
- **opencode v2.0.23→v2.0.26** (`9b4ec571…`): tag edit flake.nix:54 + `nix flake update opencode`; libstdc++ wrap untouched.
- **mikromcp 1.11.0→1.13.1**: lock regen = extract npm tgz → `nix shell nixpkgs#nodejs -c npm install --package-lock-only --ignore-scripts`; lock delta = one nested dedupe entry only; src hash via `nix hash file --sri`; npmDepsHash via placeholder→build-failure→real (`sha256-u8529N9…`).
- **zcode 3.11.2→3.14.5**: ⚠️ OLD 3.11.2 AppImage PURGED from CDN (404) — pin had become unbuildable; ⚠️ CDN has NO version feed (all latest.json/yml 404) and HEAD requests lie (404 on existing files) — only ranged GET (`curl -r 0-0`) is trustworthy; probed ladder found 3.14.5 (2026-10-08).
- **lanzaboote v1.1.0→v1.2.0** (`c1c5edd3…`): v1.2.0's ONLY change = Measured Boot PCR4 coverage — config uses NO measured boot (grep-proven) → effective no-op; note "reboot between consecutive bootloader updates" (n/a here). lzbt-systemd-1.2.0 confirmed in toplevel.
- **NO ACTION**: lucid v1.20 == upstream main HEAD (patch layer 001/104/111/113-120 untouched, no re-triage); dank-greeter 1.6.2 == latest release; ryzen-smu d298366 == repo tip; colloid fe11342 + fluent c8a244f == HEAD.

QC (all exit 0): toplevel (quickshell compiled + lzbt 1.2.0), activationPackage + both eval greps (stateFiles ok / quickshell engine floor ok), `nix flake check` (statix/nixfmt/deadnix), dry-build yoga. Closure spot-check: mikromcp-1.13.1 + opencode-2.0.26 + zcode-3.14.5 in act, quickshell-wrapped-0.3.2 + lzbt-systemd-1.2.0 in toplevel. Backups in /tmp/app-updates-dk/backup/.

USER PENDING: switch → `systemctl --user restart lucid` → smoke (bar/launcher/lock, German patches, WiFi connect re-test — 0.3.2 changed AP-security preference, greeter next boot, relaunch zcode, `opencode --version`) → then raise minQuickshell to 0.3.2; still open from prior round: 3× lucid restart stress. See [[lucid-german-round2-iconfix-2026-10-10]], [[quickshell-icon-race-fix-2026-10-10]], [[lucid-runbook-2026-10-08]].

**FOLLOW-UP 2026-10-11: minQuickshell RAISED 0.3.1→0.3.2** (home/lucid.nix:204, comment updated: 0.3.2 = tested pairing with lucid v1.20 + DankGreeter 1.6.2, user-verified) after user confirmed "everything works" post-switch. QC: activationPackage rebuild exit 0, floor line renders "ok" (throw message is dead code on pass — don't grep for it), index-proof = `git show :home/lucid.nix` + compareVersions(0.3.2,0.3.2)=0. Staged, uncommitted. Still open: 3× lucid restart stress (user may have implicitly covered it — "everything works").
