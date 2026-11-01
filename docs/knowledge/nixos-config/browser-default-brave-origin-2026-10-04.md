---
name: browser-default-brave-origin-2026-10-04
description: Firefox pinned default + Brave Origin-mode policies EXECUTED (all
  edits done, QC green, unstaged) — user must switch + sudo rm old bloat.json
  both copies; brave://policy Origin-key check pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_6fea8d75-df31-4d7e-81aa-e8c98417719f
---

EXECUTED 2026-10-04 on lucid-testing (plan approved; combined-state QC green: flake check 4 hosts + lints, dry-build yoga+latitude, home-files mimeapps.list byte-verified, brave wrapper args eval-verified). My edits UNSTAGED (worktree) except modules/features/brave.nix (git add); parallel litellm session staged .sops.yaml + hosts/nix-media/* + modules/features/litellm.nix + secrets/hosts/nix-media-litellm.yaml concurrently — validated that combined state.

What was done:
1. **Firefox = pinned default**: `home/browsers.nix` xdg.mimeApps.defaultApplications (text/html, text/xml, xhtml+xml, http, https → firefox.desktop) inside `mkIf cfg.firefox.enable`. mimeapps.list becomes HM store symlink → Brave runtime writes fail, default survives reboot without persistence entry; changing default = flake edit now. PDF/image mimes deliberately unpinned (Brave's desktop files still win those — unchanged behavior).
2. **`modules/features/brave.nix`** (NEW, in features/default.nix imports): `features.brave.enable` (yoga+latitude) → environment.etc."brave/policies/managed/origin.json" — 19 policies: BraveOriginFeatureEnabled=true (Origin upgrade mode, free on Linux since 1.91; policy name verified in deployed brave ELF 1.96.59), DefaultBrowserSettingEnabled=false, BackgroundModeEnabled=false, MetricsReportingEnabled=false, full debloat (Rewards/Wallet/VPN/News/Talk/Tor/Leo/Playlist/Speedreader/Wayback/WDP/P3A/StatsPing off). User's former hand-maintained bloat.json entries folded in: **SyncDisabled=true, DnsOverHttpsMode="automatic"** (deliberate user choices, preserved). bloat.json persistence entry removed from hosts/yoga/default.nix.
3. `--no-default-browser-check` added to HM programs.brave commandLineArgs default.
4. zcode deep-link handler folded into HM mimeapps (hosts/yoga/home.nix) — its runtime write of the entry stops working once the file is a store symlink.

Gotchas learned:
- **statix fires at a THIRD same-prefix key in one file**: 2 separate `xdg.*` assignments were fine for years, my `xdg.mimeApps` made 3 → flake check statix error → merged all three (desktopEntries+mimeApps+userDirs) into one `xdg = { }` block. Same class as the systemd.* 3-key lesson in [[libvirt-default-network-bounce-2026-09-30]].
- Subagent Bash AND harness Read could NOT see host /etc/brave (both reported missing; user corrected — file existed). Extends [[zcode-shell-sandbox-etc]]: Read tool shares the sandbox illusion for /etc.
- Agent-supplied "deployed brave 1.95.101" was stale; live binary = 1.96.59 (grep -a the ELF at opt/brave.com/brave/brave in the store path — nixpkgs layout, not share/brave).

USER STEPS REMAINING (not done): switch yoga; `sudo rm /etc/brave/policies/managed/bloat.json /persist/etc/brave/policies/managed/bloat.json` (leftover hand file merges harmlessly until removed — origin.json wins key conflicts alphabetically); verify xdg-open https → firefox, brave://policy all keys no errors, Rewards/Wallet/etc icons gone, default survives reboot. If BraveOriginFeatureEnabled shows "unknown policy" in this build → acceptable, explicit disable list still delivers; drop that key in a follow-up. Deferred: packaging real standalone Origin (laptop-updates.brave.com/latest/origin) — not in nixpkgs stable/unstable (checked 2026-10-04).
