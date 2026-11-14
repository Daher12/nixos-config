---
name: niri-autologin-plan-2026-11-14
description: yoga-niri autologin plan — never existed (intentional trial-attr
  comment), plan ready ExitPlanMode DENIED, nothing executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5cc2e7ec-3b9d-42c3-9e4e-2d65d7654c4e
---

User asked 2026-11-14 why niri autologin "seems disabled" — answer: yoga-niri NEVER had autologin in any commit. It was born the "trial attr" (2ff4f37, 2026-11-06) with the explicit comment still at profiles/desktop-niri.nix:4-5 ("greeter shows first"). The Noctalia swap (fee3af7) and 8f1e69e greeter fixes (impermanence only) never touched it. Autologin the user remembered = yoga (Hyprland/lucid, greeter.autoLogin mkDefault true since 19ef62e) and yoga-gnome/latitude (GDM).

**PLAN ready, ExitPlanMode DENIED — NOTHING executed.** User chose via AskUserQuestion: autologin + lock at boot (Hyprland parity).

Plan (2 files, both tracked → no staging trap):
- modules/features/desktop-niri.nix: add `greeter.autoLogin` option (bool, default false); `noctaliaLockAtBoot` script copying lucidLockAtBoot contract (uptime gate <240s, 50×0.2s retry) calling `noctalia msg session lock` (the exact Mod+L IPC, home/niri.nix:366), binary via `config.home-manager.users.${mainUser}.programs.noctalia.package`; mkIf (greeter.enable && autoLogin): `services.greetd.settings.initial_session = { command = "${config.programs.niri.package}/bin/niri-session"; user = mainUser; }` + noctalia-lock-at-boot user unit (After=WantedBy graphical-session.target, load-bearing ordering per 2026-09-25 stall lore).
- profiles/desktop-niri.nix: `greeter.autoLogin = mkDefault true` + rewrite stale "trial attr" comment (daily driver now).

Key facts:
- noctalia-greeter upstream module (v1.7.0, nix/nixos-module.nix) sets ONLY greetd default_session — does NOT translate services.displayManager.autoLogin into initial_session (unlike dms-greeter's module) → initial_session must be wired manually; don't set the generic autoLogin options (inert/misleading).
- Keyring needs NO new wiring: PAM "login" already keyring-wired at desktop-niri.nix:101-102 — Noctalia lock-screen unlock unlocks gnome-keyring.
- initial_session only fires at boot; logout still returns to the greeter.
- No niri VM test exists (grep tests/ = zero niri coverage) → recommend skip VMs; gate = test-suite fast + `scripts/test-suite fast yoga-niri` (yoga-niri NOT in the default trio) + nix eval probes of initial_session and the user unit.

Related: [[shell-strategy-converge-niri-noctalia-2026-11-07]], [[noctalia-niri-swap-exec-2026-11-06]], [[niri-testing-trial-2026-11-05]]
