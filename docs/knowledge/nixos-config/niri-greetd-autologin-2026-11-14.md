---
name: niri-greetd-autologin-2026-11-14
description: "EXECUTED+QC green (STAGED): yoga-niri greetd autologin behind
  Noctalia lock screen — greeter.autoLogin option, noctalia-lock-at-boot unit;
  upstream noctalia-greeter module does NOT translate
  services.displayManager.autoLogin"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5cc2e7ec-3b9d-42c3-9e4e-2d65d7654c4e
---

# yoga-niri greetd autologin (executed 2026-11-14)

## History answer (was it intentional?)
yoga-niri NEVER had autologin — deliberate: attr created as "trial" (2ff4f37, 2026-11-06) with comment "no autoLogin — the greeter shows first so the session choice is explicit". Greeter updates (fee3af7 Noctalia swap, 8f1e69e impermanence-only) never touched it. Autologin the user remembered = yoga (Hyprland, since 19ef62e) + yoga-gnome/latitude (GDM) — all still on.

## What was changed (STAGED, not committed; switch pending user)
- `modules/features/desktop-niri.nix`: new `greeter.autoLogin` option (default false; `greeter` restructured into a nested set — no external refs existed); `noctaliaLockAtBoot` script (lucid contract copy: uptime gate 240 s, 50 × 0.2 s retry `noctalia msg session lock`); `mkIf (greeter.enable && greeter.autoLogin)` block wires `services.greetd.settings.initial_session = { command = "…niri-26.04/bin/niri-session"; user = mainUser; }` + `noctalia-lock-at-boot` HM user unit (oneshot, After=/WantedBy= graphical-session.target).
- `profiles/desktop-niri.nix`: `greeter.autoLogin = lib.mkDefault true` (statix forced nested `features = { desktop-niri = {…}; }` grouping — repeated flat keys FAIL the gate).

## Load-bearing facts
- **Upstream noctalia-greeter module sets ONLY `default_session`** — it does NOT translate `services.displayManager.autoLogin` into `initial_session` (unlike dms-greeter's module). Manual `services.greetd.settings.initial_session` is the only path.
- Lock IPC = `noctalia msg session lock` (same as Mod+L bind, home/niri.nix:366); binary resolved via `config.home-manager.users.${mainUser}.programs.noctalia.package` (same noctalia-5.4.1 the shell service runs).
- Keyring: PAM "login" was already keyring-wired (desktop-niri.nix) — no PAM changes needed; unlock at lock screen unlocks gnome-keyring.
- initial_session fires at BOOT only; logout → greetd falls back to default_session (noctalia-greeter). Verified via eval.

## QC evidence
fast green (yoga yoga-niri latitude nix-media); eval probes: niri initial_session correct, yoga attr dms-greeter autologin untouched, lock unit shape + script content verified. VM battery SKIPPED by user decision (suggest mapped host-units-smoke, but that VM boots latitude — unrelated coverage; no test imports desktop-niri).

Related: [[niri-dwt-palm-rejection-2026-11-11]], [[branch-promotion-exec-2026-11-11]]
