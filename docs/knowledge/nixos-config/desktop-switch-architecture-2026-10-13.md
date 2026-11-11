---
name: desktop-switch-architecture-2026-10-13
description: Hyprland/GNOME desktop switch on yoga = flake attr pair (yoga vs
  yoga-gnome), 0 config edits — full wiring map + open validation
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b5f11292-df22-432e-aaa7-cbb24f462771
---

User asked 2026-10-13 how Hyprland and GNOME are wired, goal "max 1 manual edit" to switch. Answer: **already 0 edits — the switch is the flake attr**: `sudo nixos-rebuild switch --flake .#yoga` (Hyprland+UWSM+Lucid+DankGreeter) vs `.#yoga-gnome` (GNOME+GDM). `scripts/update-safe` accepts `yoga-gnome` (but nus pulls + bumps inputs — plain nixos-rebuild is the light path for a flip).

Wiring chain: flake attr (flake.nix:249/266, identical except profiles list) → profile sets `features.desktop-{hyprland,gnome}.enable` → feature module pushes HM flips (`desktop.hyprland.enable` desktop-hyprland.nix:155, `desktop.lucid.enable` :310). Mutual-exclusion assertions both directions. Same hosts/yoga/* files both attrs; `features.desktop-gnome.autoLogin = true` at hosts/yoga/default.nix:195 is inert on the hyprland attr.

Everything cascades off those flags: GTK settings.ini owner (lucid envtool vs HM gtk module, theme.nix:198), darkman only `!hyprland` (:219), kitty opacity branches (terminal.nix:153/168), battery-refresh daemon hyprctl vs gnome-monitor-config, keyring PAM (greetd+login vs gdm), polkit/notifications/idle (lucid vs GNOME shell). Round-trip safety: `home-manager.backupFileExtension = "backup"` at lib/mkHost.nix:64 (flipping back to GNOME moves lucid's ini files aside, no activation abort); lucid pins/patches lazily unevaluated on GNOME attr; impermanence carries BOTH stacks' state (gdm, dms-greeter, quickshell, gtk dirs).

Open item: yoga-gnome attr not dry-built recently despite heavy churn in shared files (theme/terminal/yoga home.nix) — eval covered by flake check, but a dry-build of `.#yoga-gnome` was proposed and not yet run (plan-mode ExitPlanMode was denied). Related: [[hyprland-dms-setup]], [[lucid-integration-plan]].

2026-11-12 (now trio, user Q&A): `yoga-niri` (niri+Noctalia+noctalia-greeter) is the third attr; exactly one desktop stack exists per generation (assertions), and the attr name IS the desktop choice baked into that generation. Two user-facing mental-model points worth repeating: (1) the greeter lists only the sessions of the built generation — session choice is per-REBUILD, not per-login; (2) TRAP: bare `nixos-rebuild --flake .` / `.#yoga` defaults to the HOSTNAME attr → builds Hyprland+lucid and silently flips the machine off niri; while daily-driving niri every rebuild must name `yoga-niri` (`nus yoga-niri switch`). Also: git promotion/branch merges deploy NOTHING — the running system is the last-activated generation; only a root `switch` (user-run, agents sudo-blocked) reconciles git and machine.
