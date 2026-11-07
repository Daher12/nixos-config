---
name: shell-strategy-converge-niri-noctalia-2026-11-07
description: DECISION + finishing EXECUTED+QC green (staged, niri-testing) — niri+Noctalia daily driver, no fourth shell; lang=de / dock-off harvest / KillMode=process; pending user switch
metadata:
  node_type: memory
  type: project
  originSessionId: session_a869b5f0a0004a7aa7f8e7dc29075a02
---

DECISION (user, 2026-11-07): finish niri + Noctalia on niri-testing and **use it as the daily driver**. No new shell evaluation. Assessment: all three tries (lucid / DMS / Noctalia) are the SAME spec (frosted-lofi grayscale, identical Super+R/L/V/N/P/TAB keybinds, same components, Google Sans Flex from the lucid input in all three) on two engine classes — quickshell (lucid+DMS, 427MB) vs native C++ (Noctalia v5.4.1, ~50MB-class). Compositor choice ≈ shell choice: Hyprland→lucid/DMS, niri→Noctalia. LEGO route (waybar+fuzzel+swaync) rejected for cohesion; middle path noted (Noctalia modules individually toggleable).

Landscape checked Nov 2026: WayShell = Sway-only alpha (no lock, no multi-monitor); Kitshell = Flutter/Dart alpha; AGS/Astal = patch-tax reborn; niri docs themselves now recommend DMS or Noctalia. Web claims "Noctalia v5 = quickshell" are WRONG (source-verified C++).

**Finishing EXECUTED same day (all staged on niri-testing, QC green: `test-suite fast yoga yoga-niri` OK; real home-files build = checkConfig PASS; `nix eval` showed KillMode=process on the unit):**
1. `home/noctalia.nix`: `shell.lang = "de"` (de.json shipped upstream; empty would follow LANG — system i18n.defaultLocale already de_DE.UTF-8 → lucid's 318-rule dictionary tax GONE), `dock.enabled = false` (harvested live state; geometry kept for GUI re-enable), `systemd.user.services.noctalia.Service.KillMode = "process"`.
2. `scripts/update-safe`: `yoga-niri` added to host allow-list (was "Invalid host" → `nus yoga-niri switch` failed) + usage example.
3. `scripts/test-suite`: DEFAULT_FAST_HOSTS += yoga-niri (deployed attr in the standing gate; CI already dry-builds it).
4. flake.nix yoga-niri comment de-staled (Noctalia + noctalia-greeter, not DMS/DankGreeter).
5. REPO_OVERVIEW.md noctalia row synced (templates ON with btop/gtk3/gtk4, three-pill capsule_group bar, dock off, direct-fork + KillMode).
6. `home/terminal.nix` (rice polish) staged. VM battery SKIPPED per approved plan — only `host-units-smoke` mapped and it boots headless (noctalia.service is a user unit on graphical-session.target, unreachable in VM).

Facts: noctalia.service generated unit has no KillMode + Restart=on-failure + **X-Restart-Triggers=noctalia-config.toml** → every config-changing switch restarts the shell; default control-group KillMode killed ALL launched apps (zcode included) — hence KillMode=process (alternative `launch_apps_as_systemd_services = true` declined: dock-click latency, measured at the 60Hz confound). `[shell] lang` follows LC_ALL>LC_MESSAGES>LANG. Lockscreen resurrection race SELF-RESOLVED: state file now carries the compact 400px capsule — no strip needed. **update-safe REFUSES a staged-dirty flake.lock** → `nus` blocked until the staged niri-testing bundle is committed; first switch via `sudo nixos-rebuild switch --flake .#yoga-niri`, run from a Mod+T kitty (niri-spawned), not a dock-launched one.

**Pending user:** switch (staged bundle incl. kitty frost NEVER switched as of 2026-11-07 — see [[niri-window-policy-frost-plan-2026-11-07]] round 4), `systemctl --user start battery-refresh` once, 120Hz verify (`niri msg outputs`), German-UI + lock + screencast smoke, close ALL kitty (single-instance trap), then a week of daily use → harvest `noctalia config export merged` → commit (unblocks nus).

**Round 5 (user live feedback, same day) — three reports, root-caused + fixed (staged, QC green):**
1. zcode edge-to-edge ROOT CAUSE (niri source, src/handlers/xdg_shell.rs): the `open-maximized-to-edges=false` deny only gates the INITIAL configure (`wants_maximized && rules.open_maximized_to_edges.is_none()`); `maximize_request()` on an ALREADY-MAPPED window calls `layout.set_maximized(true)` UNCONDITIONALLY — no rule gate. Firefox asks at map (denied → maximized column); zcode/Electron asks after map (granted → to-edges). Fix: `zcode-unmax` wrapper (home/niri.nix) — launch, poll `niri msg -j windows` for a NEW zcode window with tile_width >= output_width-6 (only to-edges can exceed the maximized-column width, which keeps gaps), then `maximize-window-to-edges --id` (exit lands in maximized column; second maximize-column only if it came back < width-30 — observed once). Desktop entry routed via `xdg.desktopEntries.zcode.exec = mkForce "zcode-unmax --no-sandbox %U"` (entry deploys to /etc/profiles/per-user/dk/share/applications in this HM pin, NOT ~/.local/share — obsidian comment in hosts/yoga/home.nix). Live window fixed manually via the same two actions (1536x925 → 1512x901). Terminal `zcode` untouched; yoga attr untouched.
2. Focus ring too loud/big in light mode: width 2→1, `#c4a7e7ff`→`#c4a7e799` (60%).
3. New bind `Mod+Ctrl+F → maximize-window-to-edges` (niri's default Mod+M is btop) — was NO escape hatch from to-edges at all.
4. kitty focused-opaque RESOLVED by fresh-instance test (single-instance trap, 4th occurrence): client-driven blur works in every state; user asked "a tad more frost" → `background_opacity` 0.80→**0.75** on the noctalia host (home/terminal.nix, QC green ×4 hosts). Knob reminder: opacity IS the frost strength on niri.
Bonus facts: `niri msg action <action> --id N` supported (verified maximize-window-to-edges/focus-window); `niri msg -j windows` exposes layout.tile_size (used as state proxy).
**PROVEN LIVE by user:** zcode-unmax "worked flawlessly"; ring 1/60% accepted.

Related: [[stack-comparison-research-2026-11-07]], [[noctalia-niri-swap-exec-2026-11-06]], [[battery-refresh-niri-broken-2026-11-06]], [[niri-rice-polish-2026-11-07]], [[plans-for-weaker-executor]].
