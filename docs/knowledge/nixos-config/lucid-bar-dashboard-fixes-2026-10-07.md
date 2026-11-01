---
name: lucid-bar-dashboard-fixes-2026-10-07
description: Four new lucid patches 103-106 (LUKS disk fix, mic+volume-label
  hide, dashboard tiles dropped, mpris shown-slot) + statix mimeApps fix —
  STAGED, switch pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_ae69deb1-8618-4e78-b8b7-01caac691280
---

2026-10-07, executed the approved 5-item lucid bar/dashboard plan (mic indicator, floating tray, volume number, dashboard tiles, 0/932 GB disk card). ALL STAGED on main (index), **never committed, switch pending** — user switches via `nus` then visually verifies.

**New patches in `home/lucid-patches/`, appended to `lucidPatched` after 102** (generated against the fully-patched tree `/nix/store/c4nxzdxvi7j8hh26xvn3sgiv6ms12d2w-lucid-source-1.10.5-local`, chain-tested 103→106 clean, result byte-compared):
- `103-luks-disk-usage.patch` — System.qml disk card: lsblk gains PKNAME, df sources walked up the parent chain (mapper/cryptroot → nvme0n1p2 → nvme0n1) + seen-once dedupe (btrfs mounts one device per subvolume, upstream would sum them). Root cause of "0 / 932 GB": LUKS source name matched neither the exact nor the partition-suffix regex. Algorithm simulated against live data → **104 / 932 GB** expected.
- `104-bar-indicators.patch` — volIndicator `labelText: ""` + StatusIndicator label `visible: labelText !== ""` + micIndicator `visible: false` (user chose hide-completely over muted-only).
- `105-dashboard-tiles.patch` — Spielmodus + Energie ToggleTiles DELETED (user choice). Root facts: Energie = power-profiles-daemon D-Bus via Quickshell `PowerProfiles`; yoga runs TLP (`power-tlp.nix` asserts PPD off), quickshell 0.3.1 silently reports Balanced and drops clicks — inert decoration. Spielmodus = only runs user-configured cmds (empty). If ever made real: swap TLP→PPD or wire gameMode cmds.
- `106-mpris-shown-slot.patch` — root cause of floating tray = our own 003 patch set `visible` but not `shown`; BarPill reserves slot width from `shown` (BarPill.qml:119). Now `shown: Prefs.showMedia && root.player !== null`, 003's visible-override removed. Same show-condition as 003, but width collapses.

**Volume number clarification:** the "5/10/15 next to the speaker" was the BAR System pill (System.qml volIndicator), not the bottom-center OSD popup (lucidosd/Osd.qml — untouched, still shows big % there).

**statix fix (asked user, approved):** flake check had been RED since d1b20f9 (obsidian handler pin added a second mimeApps block → statix "repeated keys" on hosts/yoga/home.nix — pre-existing, unrelated to lucid work). Merged the 3 assignments into one `mimeApps = { ... }` attrset; byte-proof: `nix build ...home-files` + diff generated vs deployed `.config/mimeapps.list` → identical. flake check exit 0 after.

**Gotchas hit:** sandbox shell /tmp is namespaced — file tools can't see it, work trees must live under ~/.cache; `ls -dt /nix/store/*lucid-source*` picks STALE paths (mtime unreliable) — query the built closure via `nix path-info -r <system>` instead.

Staged set: 4 patches + home/lucid.nix (also carries the parallel F-row work — unavoidable, flake reads index) + REPO_OVERVIEW.md (patch inventory extended) + hosts/yoga/home.nix (statix). Unstaged other-session files (bluetooth.nix bt-agent, hosts/yoga/default.nix FnLock tmpfiles) left alone.

Related: [[lucid-buildtime-patches-2026-09-28]], [[yoga-fnlock-frow-2026-10-06]], [[lucid-bluetooth-pairing-agent-2026-10-06]]
