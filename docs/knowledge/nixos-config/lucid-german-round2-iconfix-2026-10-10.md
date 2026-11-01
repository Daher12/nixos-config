---
name: lucid-german-round2-iconfix-2026-10-10
description: Round 2 EXECUTED — 114 date-line locale fix, new 119 session
  German, 201 reworked from mutex to GUI-thread marshaling (mutex =
  wedge→fallback icons), gsettings env vars on lucid.service; STAGED,
  switch+restart+visual pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_27757192-3f4b-4fae-bc1e-a19dd6ecfd26
---

Executed 2026-10-10 pm (second polish round, planned in-session and executed after plan approval):

1. **Dashboard date root cause**: the English date above "läuft X Std" was `System.qml:1528` `Qt.formatDate(root.nowDate, "dddd, d MMMM")` — QML's `Qt.formatDate` uses Qt's default locale which stayed English EVEN WITH the LANG=de_DE.UTF-8 pin (the pin only drives `toLocaleDateString(Qt.locale(), …)` surfaces + numeric clockDateFormat). Fix inside [[lucid-v120-polish-plan-2026-10-10]]'s patch 114: explicit `root.nowDate.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM")`.
2. **New patch 119-german-session.patch** (user picked scope "date + session/power", fetch widget stays English): SessionMenu.qml ("Energie" header matching 114's Power.qml wording, läuft-T/Std/Min uptime chip) + lucidsession/Session.qml ("Bis bald, …", "Erneut drücken zum Fortfahren, Esc zum Abbrechen", "Läuft seit …" — `Sys.duration()` left English, shared with FetchWidget). Layer now 10 patches.
3. **Icon regression root cause (fixes yesterday's quickshell-icon-race memory approach)**: patch 201's QMutex turned the race into a DEADLOCK — reader thread wedged inside requestPixmap (Qt internally dispatches pixmap creation to the GUI thread while our mutex is held; GUI thread blocked on the same mutex), every icon queued behind it → silent generic fallbacks, no warnings. Reworked 201: whole body moved into `requestPixmapInGuiThread` (anonymous-namespace static), wrapper hops off-thread requests to GUI thread via `QMetaObject::invokeMethod(app, …, Qt::BlockingQueuedConnection)`, runs inline on GUI thread, NO mutex (can't deadlock: GUI thread never waits on the reader). nm-verified: new binary has `requestPixmapInGuiThread` (2 syms), `requestMutex` gone (old had 1).
4. **gsettings hardening** (lucid.service Environment): `GSETTINGS_SCHEMA_DIR=${gsettings-desktop-schemas}/share/gsettings-schemas/${name}/glib-2.0/schemas` + `GIO_EXTRA_MODULES=${dconf.lib}/lib/gio/modules` — repro'd under exact unit env before enabling: bare = "No schemas installed"; schema-only = **wrong value 'Adwaita'** (no dconf GIO module → reads defaults, would have misled IconTheme.qml watcher); both = 'Fluent' ✓. The dconf GIO module lives in the `dconf.lib` OUTPUT (not `dconf` out). lucid-auto-mode NOT touched (its dconf fallback works; ~6s retry noise per boundary remains — optional follow-up).

QC: P2 real-build clean (no fuzz/offset), both eval gates ok, Appendix A all pass incl. 5 new 119 markers + 114 toLocaleDateString marker, cumulative work-tree == $SRC byte-identical (runbook "all" gate), attribution 41 files all inventory-mapped, toplevel built (new wrapper dzcm16kg), flake check + dry-build exit 0. STAGED (never committed).

Gotchas hit: python `write_text` on a `cp -al` hardlink snapshot truncates the SHARED inode → empty 119 diff (prev==work); rebuild prev via `git archive`+patches, use plain cp -r. `grep -c` returning 0 breaks `&&` chains. Wrapper bin/qs and bin/quickshell are 16KB C wrappers — real ELF is `bin/.quickshell-wrapped` (nm/strings there, binary is stripped so strings can't prove new symbols; nm can).

USER STEPS PENDING: `sudo nixos-rebuild switch --flake ~/nixos-config#yoga` → `systemctl --user restart lucid` (wrapper+tree changed → restart MANDATORY) → visual: date "Samstag, 10. Oktober", Fluent icons back, session screen (SUPER+Escape) German → 3× restart stress (icons must survive).

**FOLLOW-UP (same evening) EXECUTED + USER-CONFIRMED WORKING**: user verified everything incl. the 3× restart crash-test (icons stable, no crashes — the marshaling fix holds). Last miss: Notifications "Clear all" button → translated to "Alle löschen" by regenerating 117 (fresh tree→116, re-apply 117, sed edit, regen, re-stack 118+119; proven delta = exactly the one line; new Appendix A marker `grep -c 'Alle löschen'` = 1). Full QC re-run green (P2, cumulative tree byte-identical, flake check, dry-build). STAGED — needs one more switch; tree-only change (no wrapper/env) so a lucid restart is safe-but-optional (QML hot-reloads). Sweep found NO other English in Notifications.qml; other remaining English surfaces (out of scope, noted): luciddocks/ClipPreview "Clear", lucidprefs LauncherPage/NotificationsPage/StoragePage strings (settings pages + fetch widget stay English by user choice).
