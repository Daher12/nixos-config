---
name: impermanence-xbel-heal-fix-2026-11-25
description: recently-used.xbel persist-files failure root-caused + fixed — xbel
  dropped, generic persist-heal hook added
metadata:
  node_type: memory
  type: project
  originSessionId: sess_da64fe25-413a-4c1f-bb94-486cfa94b329
---

EXECUTED 2026-11-25, fast green, UNCOMMITTED (staged only). Switch pending (user runs it).

**Root cause (verified, not guessed):** every boot rolls back btrfs `@` from `@blank`, and `/persist/home/dk/.local/share/recently-used.xbel` had NEVER existed → impermanence `mount-file.bash` (method auto) fell through to `ln -s`, leaving a **symlink**. GTK apps save recents atomically (temp file + `rename()`), and rename **replaces the symlink with a plain file**. Next switch: plain non-empty file hits the `elif [[ -s $mountPoint ]]` guard → "A file already exists at ..." → `persist-files` fails → switch exits 2 → `update-safe` aborts (after committing the lock bump — commit happens BEFORE activation). Manual backup+delete always reset to step 2 → structural loop. The entry added in audit 2026-11-18 ("last impermanence gap") never persisted anything. Upstream: impermanence issue #147 ("Binding doesn't work — Gnome just doesn't write to the file"; rename hits EBUSY on bind mounts, so a bound xbel would freeze instead).

**Fix (user chose drop+heal over copy-sync and keep+heal):**
1. `hosts/yoga/home.nix` — xbel removed from `files`; comment explains why. Recents reset per boot (their real behavior all along).
2. `modules/features/impermanence.nix` — `persist-heal` hook: `system.activationScripts.persist-files.text = lib.mkBefore ''...''` prepends a `persist_heal_file` function + one generated line per persisted file. Guards: `[[ -f "$mp" && ! -L "$mp" ]] && ! findmnt` → if /persist source missing: **migrate** (cp -p into /persist, rm stray → real bind forms on next mount attempt); else **backup** to `/persist/heal-backups/<sanitized>.bak` (persisted copy wins) + rm stray. No-op on symlinks/mounts/absent files. Covers the whole victim class: monitors.xml (mutter atomic-writes it in the yoga-gnome attr), user-dirs.locale, machine-id/ssh keys on bind loss.

**Implementation facts:** impermanence pinned rev `fa627f4` — entries normalize to submodules with `filePath` (full mountpoint) + `persistentStoragePath`; `concatPaths` importable via `pkgs.callPackage "${inputs.impermanence}/lib.nix" {}`; HM entries bridge into the same eval via `config.home-manager.users.<u>.home.persistence`. Generated list = 8 files (5 system + 3 HM). Verified by `nix eval` of the generated snippet (function first, mount script last) + 4-scenario /tmp sandbox test (migrate, backup, symlink no-op, empty-file migrate).

**Gotcha for future file-persistence entries:** never persist a file that an app saves via atomic rename (any `g_file_set_contents`-style writer) — symlink gets destroyed, bind silently freezes writes; only dirs or copy-sync survive such writers.

**One-time transition trap (found in QC 2026-11-25, NOT automated by user choice):** removing a `files` entry retires its `persist-*` unit. Its ExecStop is `[[ -L mp ]] && rm mp || (umount mp; rm mp)` under `set -eu`, so a stray plain file (or a missing path) at stop time fails the job. The 26.05 switch tool (Rust `switch-to-configuration-ng`) reports ANY unit left failed and exits 4 — the system still switches, but a ghost failed unit keeps every later switch at exit 4 until `systemctl reset-failed` or reboot. User fix: put a symlink at the path right before switching (`ln -sf /persist/home/dk/.local/share/recently-used.xbel ~/.local/share/recently-used.xbel`). Hook deliberately left at its first verified version: it also acts on empty strays and does not filter disabled HM persistence roots (both latent-only). User pushed back on hardening mid-QC ("should be an easy fix, why so complicated") — keep fixes minimal, don't grow scope during a quick-validation turn.
