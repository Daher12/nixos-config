---
name: yoga-iwd-band-flap-fix
description: yoga 5GHz/2.4GHz band flapping root-caused to iwd roam thresholds;
  fix COMMITTED 2026-10-06 (5df41f6), activation VERIFIED LIVE 2026-10-28
metadata:
  node_type: memory
  type: project
  originSessionId: sess_68ffb521-1637-446e-9d21-23454947acf2
---

yoga wifi band flapping (user complaint 2026-10-05): NOT NetworkManager — iwd (NM's backend) made 617 `roam-info` events / 134 FT roams in one boot (prior boots: 1–3), ping-ponging between BSSIDs `04:f4:1c:72:ae:56` and `08:55:31:45:84:34` of the single mesh SSID `FRITZ!Box 7590` (AVM + MikroTik radios). Mechanism: signals at the usual spots (-63…-77 dBm) sit exactly at iwd's default roam thresholds (-70 dBm 2.4G / -76 dBm 5G). Kernel powersave already off (exonerated); NM per-connection `band=`/`wifi.powersave` inert under iwd backend (e5ca1e1).

Fix STAGED 2026-10-06 in `hosts/yoga/default.nix` (`networking.wireless.iwd.settings`): `RoamThreshold=-74`, `RoamThreshold5G=-80`, `Rank.BandModifier5GHz=2.0` (user chose "lazier roaming + 5GHz bias" over pinning). REPO_OVERVIEW.md Known Gotchas entry added. QC green (eval exact, dry-build exit 0). NOT switched.

**Why:** spellings matter per deployed iwd 3.12 `iwd.config(5)`: `RoamThreshold5G` (not 5Ghz) and `Rank.BandModifier5GHz` (not 5Ghz); `CriticalRoam*` left at defaults -80/-82 as must-roam floor. Executor-agent handoff for this plan HALTED (inherited plan-mode sandbox) — main agent executed directly instead; [[plans-for-weaker-executor]] runbook style was still what made that instant.

**How to apply:** activation = `sudo nixos-rebuild switch --flake .#yoga` THEN `sudo systemctl restart iwd` (switch alone may not restart the daemon; wifi blips ~5 s); verify `cat /etc/iwd/main.conf` shows the three keys. Success metric: `journalctl -u iwd --since today | grep -c roam-info` drops from ~200/day to single digits. Revert = delete the three keys + re-switch. Open follow-ups: regdom is `country 00` (DFS passive-scan on 5G; `DE` would be separate change), duplicate never-used NM profile `FRITZ!Box 7590_2` (runtime `nmcli connection delete` candidate). Related: [[obsidian-litellm-integration]] also staged pending nix-media switch — separate host.
