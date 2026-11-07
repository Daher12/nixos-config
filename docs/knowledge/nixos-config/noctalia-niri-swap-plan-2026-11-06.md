---
name: noctalia-niri-swap-plan-2026-11-06
description: PLAN ready (ExitPlanMode DENIED, NOTHING executed) — swap
  DMS→Noctalia v5.4.1 on yoga-niri (branch niri-testing); user decisions
  noctalia-greeter / blurred overview / wallpaper-muted; full Noctalia v5.4
  research facts inside
metadata:
  node_type: memory
  type: project
  originSessionId: session_5f42e28180299905086e0ffc15006d65
---

PLAN-ONLY session 2026-11-06 (plan mode, ExitPlanMode denied): replace DMS with **Noctalia v5.4.1** on the `yoga-niri` attr, branch `niri-testing` (2ff4f37). Only the niri path changes — `yoga` Hyprland attr keeps DMS/dux-shell untouched. Staged-never-committed. Reference file to adapt: `git show ebd8d8d:home/noctalia.nix` (Sep attempt, branch noctalia-testing still exists locally).

**User decisions (locked):** noctalia-greeter (not keeping dms-greeter); blurred overview backdrop (layer-rule `^noctalia-backdrop` place-within-backdrop + `[niri/backdrop]` enabled); theme seed = wallpaper-muted (mode auto, source wallpaper, scheme muted), grayscale palette port = later live-tune+harvest.

**Noctalia v5.4.1 research facts (docs.noctalia.dev, fetched 2026-11-06):**
- C++ shell (v4 quickshell unmaintained); NOT in nixpkgs (MCP index empty) → flake `github:noctalia-dev/noctalia` **without follows** + cachix `noctalia.cachix.org` key `noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=` (follows disables cache). HM module `homeModules.default` (installs package + noctalia.service via `systemd.enable`); NixOS module + recommendedServices NOT needed (NM/BT/upower hand-managed, TLP ppd conflict).
- Greeter: flake `github:noctalia-dev/noctalia-greeter`, `nixosModules.default` → `services.displayManager.noctalia-greeter { enable; settings; }` — enables greetd/AccountsService/Polkit itself, no compositor option (greeter lists installed Wayland sessions; `[session].default = "niri"`, remembered in sync.toml at /var/lib/noctalia-greeter).
- Ships BUILT-IN: polkit agent (`polkit_agent = true`, Settings→Security), lock screen (PAM hardcoded "login"), idle daemon (lock_before_suspend incl. lid-close), clipboard manager, wallpaper daemon → drop hyprpolkitagent-equivalents, drop wl-paste/cliphist spawn in niri config.
- IPC verbs: `panel-toggle launcher|session|clipboard|control-center <tab>`, `settings-toggle`, `session lock|suspend|lock-and-suspend|logout|…`, `window-switcher [hold|reverse]`, `screenshot-region/fullscreen [--annotate]`, `notification-dnd-*`, `config-get/set`, `config-reload`.
- niri requirements: `debug { honor-xdg-activation-with-invalid-activation }` (typo risk — actual key `honor-xdg-activation-with-invalid-serial`) for notification actions; float settings window (app-id `dev.noctalia.Noctalia`, ~1080×920); blur works via ext-background-effects auto-published regions (niri ≥26.04 ✓) but add layer-rules `^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$` + `noctalia-window-switcher` blur-on/xray-false to avoid wallpaper-bleed at corners; 3 overview-backdrop options (blurred/stationary/flat).
- Key traps: `templates.enable_builtin_templates = false` MANDATORY (builtin templates write store symlinks → EACCES); wallpaper paths must be USER paths (store path dies at GC, #4425); wrong settings keys fail checkConfig at build (fast feedback); `niri_overview_type_to_launch_enabled` off by default.

**Wiring plan (self-contained, in chat/ExitPlanMode payload):** flake inputs noctalia+greeter no-follows + cachix in core/nix.nix; desktop-niri.nix: drop programs.dank-material-shell block, swap dms-greeter→noctalia-greeter (import greeter module exactly ONCE), HM push `desktop.noctalia.enable`; new home/noctalia.nix (HM module import, minimal settings seed); home/niri.nix: delete 10 dms/*.kdl includes, swap 6 DMS binds→noctalia msg verbs, add Alt+Tab window-switcher, add debug/float/backdrop/blur rules, keep brightnessctl 10% XF86 binds + native toggle-overview/screenshots; persistence +`.local/state/noctalia`+`.cache/noctalia` (keep all dms entries — yoga attr uses them); QC = nix fmt + test-suite fast + eval probes; VM battery SKIP (no graphical VM tests). Rollback = previous generation or git restore.

Related: [[niri-testing-trial-2026-11-05]], [[noctalia-integration]] (Sep lore: state file wins over Nix, TOML float trap, lock widgets), [[dux-shell-eval-branch-2026-11-05]], [[plans-for-weaker-executor]].
