---
name: tv-firetablet-debloat-research-2026-10-28
description: Research Q&A 2026-10-28 — cleanyourtv works on waipu.tv Stick 2
  (Android 14 TV, no curated list); Fire HD 10 2023/HD 8 2020 debloat keeps
  Amazon Kids if enforcement packages kept; UAD-ng in nixpkgs
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e31f15b2-3e80-45be-89db-3c6cc2bcc6fa
---

User hardware research (advice delivered 2026-10-28, nothing executed):

**waipu.tv Stick 2nd gen** — Amlogic S905X5M, certified Android 14 for TV, Chromecast built-in. [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) works without tool changes (needs Android TV/Google TV + network ADB + Android 8+), BUT: no curated waipu package list among the 170+ models — generic assistant-driven flow via PROMPT.md. Keep-list when debloating: waipu.tv app itself, cast receiver, setup wizard (unless Wi-Fi re-saved first). Reversible (`pm disable-user` + restore script); waipu firmware updates re-enable preinstalls. Projectivy Launcher = alternative launcher on same ADB mechanism.

**Fire HD 10 2023 + Fire HD 8 2020** — debloat possible while keeping Amazon Kids + parental guidelines: child profiles are separate Android users, `pm uninstall -k --user 0` only touches the adult profile. MUST-KEEP: `com.amazon.parentalcontrols`, `com.amazon.tahoe` (Amazon Kids UI), `com.amazon.venezia` (Appstore), `com.amazon.kindke`/kindle, `dcp`/device-management/content-platform packages, Fire Launcher + OOBE. Tool ranking for Linux: (1) UAD-ng = nixpkgs `universal-android-debloater` 1.2.0, per-package selective with risk badges; (2) Fire Tools (mrhaydendp, actively maintained, but fixed aggressive debloat list — review first); (3) Fire Toolbox frozen at V45.1, avoid its "disable all Amazon apps". Stock-launcher replacement broken on Fire OS 8.3 — plan is debloat-only. OTA updates restore apps; recommended keep-updates+re-debloat. `android-tools` in nixpkgs for adb. ADB enable needs parental-controls password while controls are on.

**Why:** user asked whether these devices can be cleaned without losing kids restrictions / TV function; recommendations were delivered and may be acted on later.
**How to apply:** if user reports follow-ups (e.g. running cleanyourtv from this session via PROMPT.md, or a broken Kids profile after debloat), this file holds the keep-lists and tool verdicts.
