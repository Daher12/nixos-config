---
name: yoga-wifi-band-flap-2026-10-06
description: yoga 5GHz↔2.4GHz flapping root-caused to iwd roam-threshold
  ping-pong on one mesh SSID; fix (RoamThreshold=-74/-80 + BandModifier5GHz=2.0)
  delivered as executor RUNBOOK TEXT 2026-10-06, NOT executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_68ffb521-1637-446e-9d21-23454947acf2
---

Diagnosed 2026-10-06 (plan-mode session). Symptom: aggressive 5GHz↔2.4GHz switching.

**Root cause (live-verified):** home SSID `FRITZ!Box 7590` is ONE mesh SSID across ~5 BSSIDs / ≥2 APs (AVM FRITZ!Box 7590 + MikroTik; consecutive-MAC dual-band pairs `08:55:31:45:84:34/35`, `d0:ea:11:9e:5d:29/2a`; flapping alternated between exactly `04:f4:1c:72:ae:56` and `08:55:31:45:84:34`). ALL switching is iwd's roam engine (`roam-scan` → `ft-roaming`, 802.11r FT, security "WPA2-Personal + FT"): 617 `roam-info` events + 134 FT roams in one 3-day boot (prior boots 1–3). NetworkManager EXONERATED — zero roam/band lines in its journal. Mechanism: both bands hover at -63…-77 dBm, exactly around iwd default roam thresholds (-70 dBm 2.4GHz / -76 dBm 5GHz) → threshold ping-pong. Also exonerated: kernel wifi powersave (already off via `iw get power_save`); NM per-connection `band=`/`wifi.powersave` and TLP `WIFI_PWR_*` are inert under the iwd backend (commit e5ca1e1).

**iwd 3.12 option spellings (from DEPLOYED man page, `zcat …/man5/iwd.config.5.gz` — do NOT trust memory):** `General.RoamThreshold` (def -70), `General.RoamThreshold5G` — spelled **5G, not 5Ghz** (def -76), `General.CriticalRoamThreshold`/-5G (def -80/-82, must-roam floor), `Rank.BandModifier5GHz` — spelled **GHz, not 5Ghz** (def 1.0; **0.0 disables the band entirely**), `Rank.BandModifier2_4GHz`, `DriverQuirks.PowerSaveDisable`, `General.DisablePeriodicScan`.

**Chosen fix (user picked "lazier roaming + 5GHz bias" over hard BandModifier2_4GHz=0 band-pin — too risky for a roaming laptop):** in `hosts/yoga/default.nix` `networking.wireless.iwd.settings`: `General.RoamThreshold = -74`, `General.RoamThreshold5G = -80`, `Rank.BandModifier5GHz = 2.0`; CriticalRoam* left at defaults. NixOS renders this to `/etc/iwd/main.conf` — an /etc change may NOT restart the daemon: activation = `nixos-rebuild switch` **+ `sudo systemctl restart iwd`** (wifi blips ~5s), then `cat /etc/iwd/main.conf`. Success metric: `journalctl -u iwd --since today | grep -c roam-info` from ~200/day (617/boot) to single digits (iwd never logs the word "roamed" — grep roam-info). Revert = delete the three keys + re-switch.

**Delivery state:** runbook text handed off 2026-10-06 as executor brief (NOT executed, NOT staged). Two edits: (1) default.nix block at lines 133–143 (old block verified byte-for-byte incl. em-dash; firewall comment starts line 145); (2) REPO_OVERVIEW.md new Known-Gotchas subsection immediately before `### Intel GPU Metrics (nix-media)` (line 498, power-tuning section ends 496).

**Out-of-scope follow-ups noted:** regdomain is `country 00` unset → passive 5GHz DFS scanning (DE candidate, separate change); duplicate NM profile `FRITZ!Box 7590_2` (same SSID, never activated) — `nmcli connection delete` candidate; AP-side FRITZ!Box mesh/band-steering tuning would complement.

Related: [[plans-for-weaker-executor]], [[zcode-shell-sandbox-etc]], [[lucid-wifi-connect-fix-2026-09-30]].
