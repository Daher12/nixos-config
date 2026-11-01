---
name: lucid-date-iconwedge-2026-10-10
description: Post-switch fallout 2026-10-10 evening — English dashboard date
  (Qt.formatDate is C-locale, LANG can't fix) + Fluent icons dead (201 mutex
  WEDGED the async reader, crash→hang); fix plan APPROVED + halted for executor
  (extend 114, add 119, rework 201)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_27757192-3f4b-4fae-bc1e-a19dd6ecfd26
---

2026-10-10 evening, after the R3 switch + `systemctl --user restart lucid` (quickshell PID 530750, started 15:22): user reported (1) English text above "läuft X Std" in the top-right dashboard, (2) Fluent icons gone — default/monogram icons in lucid menus. Both diagnosed in plan mode (2 Explore agents); plan APPROVED (chat, after ExitPlanMode rejection) and halted for the executor.

**Diagnosis 1 — date line**: `lucidbar/System.qml:1528` `Qt.formatDate(root.nowDate, "dddd, d MMMM")` renders "Saturday, 10 October". QML `Qt.formatDate/formatTime/formatDateTime` ALWAYS use the C locale for day/month names — the LANG=de_DE.UTF-8 pin can never fix this (upstream's other date surfaces use toLocaleDateString, which is why THEY are German). Patch 114 missed it because it's not a literal string.

**Diagnosis 2 — icon wedge**: quickshell patch 201's mutex is the EXACT delta between the 13:31 build (crashed but themed SVGs actively resolving — its crash report shows IconImageProvider→QIconLoaderEngine) and the 15:22 build (stable, silent monogram fallbacks, ZERO "Could not load icon" warnings, QQuickPixmapReader thread parked in userspace wait since startup). Serialized requestPixmap → reader thread wedged inside the first request → every async icon request queues forever. The mutex converted the SIGSEGV into a HANG. Mutex serializes but does not legalize cross-thread QIcon use — "no crashes" after a threading fix is NOT success; verify the payload (icons resolving) too.

**Pre-existing break (independent, ≥2026-09-27)**: gsettings CANNOT run inside lucid user units — "No schemas installed" (no gsettings-desktop-schemas in any unit XDG_DATA_DIRS, no GSETTINGS_SCHEMA_DIR). IconTheme.qml's `gsettings monitor` watcher died at startup → themeName="" → resolve-icons.sh script-walk never runs → dock/launcher 100% dependent on the (wedged) Qt provider. 117 "gsettings unavailable → dconf" warnings in lucid-auto-mode journal. Fluent theme itself fine on disk (/etc/profiles/per-user/dk/share/icons; resolve-icons.sh resolves everything when run manually). Qt's theme NAME comes from the PORTAL (XDG_CURRENT_DESKTOP=Hyprland excludes the gtk3 platformtheme auto-pick; portal answers icon-theme='Fluent' correctly).

**User decisions**: German scope = date line + session/power screens; FetchWidget labels (OS/Kernel/Uptime/…) stay ENGLISH by choice. Sys.duration() untouched (shared with fetch widget) → session screen reads "Läuft seit 1d 2h".

**Approved plan (halted for executor)**:
- Extend 114: line 1528 → `text: root.nowDate.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM")` (deterministic German, survives LANG regressions; LANG pin STAYS — clock numeric + other toLocaleDateString surfaces need it).
- New `119-german-session.patch` (no existing patch touches these files): SessionMenu.qml:122 uptime chip `"läuft " + d + " T " + h + " Std " + m + " Min"` (mirror 114 wording), :164 `"Power"`→`"Energie"` (grep 114 for its established word first and reuse); lucidsession/Session.qml:231 `"Bis bald, " + ses.who`, :238 `"Erneut drücken zum Fortfahren, Esc zum Abbrechen"` + `"Up for "`→`"Läuft seit "`.
- Icons: check quickshell master (issues #1007/#1028/#1056/#1079) for a provider fix to PORT first; else rework 201 = GUI-thread marshaling — preferred shape QQuickAsyncImageProvider + QQuickImageResponse doing the QIcon work via QueuedConnection onto qApp's thread (deadlock-free, reader never blocks); fallback BlockingQueuedConnection for sync C++ callers; DROP the mutex (single-threaded by construction).
- Hardening: `GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas` on lucid.service; verify via env -i repro expecting `'Fluent'`; add `GIO_EXTRA_MODULES=${pkgs.dconf}/lib/gio/modules` if backend fails; DROP the step if it fights (optional — provider rework alone fixes the user-visible icons).
- QC: P2 real-build, 4 new Appendix A markers (`toLocaleDateString(Qt.locale("de_DE")` / `Bis bald` / `Erneut drücken zum Fortfahren` / `läuft " + (d`, each =1), runbook §1 table + P7 smoke rows updated, flake check + dry-build, stage only.
- User relay: switch → `systemctl --user restart lucid` → dashboard date German + Fluent icons + session screen German → 3× restart stress (still pending from the original crash fix).

Also found (left English per scope): FetchWidget.qml:38-46 labels; Sys.qml:80-88 duration() "1d 2h" style. See [[quickshell-icon-race-fix-2026-10-10]] (the mutex fix this reworks), [[lucid-v120-polish-plan-2026-10-10]] (the round whose switch surfaced this).
