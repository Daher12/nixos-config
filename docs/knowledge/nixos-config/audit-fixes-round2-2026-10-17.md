---
name: audit-fixes-round2-2026-10-17
description: Review-fix round EXECUTED+QC-green STAGED 2026-10-17 — keymap de,
  key-only SSH, uid pin, microcode normalization (upstream default is FALSE),
  laptop dedup into profile, roles aggregator + ports option; pending switch
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a118bbb3-e357-4845-82b6-65be5bed79f3
---

Follow-up to the 2026-10-16 review report: user approved + I executed all P1–P3 fixes on 2026-10-17. Everything STAGED (plus a parallel session's flake.lock/flake.nix/lucid-patches/mikromcp staged work in the same index), NOT committed. QC: nix fmt, `nix flake check` (statix/deadnix/nixfmt), dry-build ×4 hosts, eval baseline/post diffs, home-files diff — all green.

Changes:
- `modules/core/locale.nix`: `services.xserver.xkb.layout = mkDefault "de"` (was GNOME-only → yoga+nix-media consoles/LUKS prompt were `us`; eval-proven). desktop-gnome.nix copy removed.
- `modules/core/openssh.nix`: `KbdInteractiveAuthentication = mkDefault false` — REAL hardening: upstream default true meant PAM kbd-interactive still offered password prompts despite PasswordAuthentication=no. Fleet policy: key or Tailscale, never passwords. nix-media stays LAN-open on 26 deliberately (comments updated).
- `hosts/yoga/default.nix`: `uid = 1000` pinned (eval was `null` before — static uid assignment did NOT happen there; live 1000 user-confirmed). yoga-gnome gets the pin too.
- Microcode: **pinned nixpkgs 26.05 defaults `hardware.cpu.{amd,intel}.updateMicrocode` to plain `false`** (decoupled from enableRedistributableFirmware — verified in store source `nixos/modules/hardware/cpu/{amd,intel}-microcode.nix`). The three per-host lines were load-bearing → normalized into `modules/hardware/default.nix` isPhysical branch (both vendors mkDefault true; wrong-vendor blob inert). yoga now pulls microcode-intel (~15MB closure). Recorded in REPO_OVERVIEW "NixOS 26.05 Breaking Changes".
- `profiles/laptop.nix`: fleet laptop baseline (core.users.description, core.openssh mgmt-LAN, nas/brave enables, nftables+openFirewall=false, big firewall/libvirt comment) — host copies deleted; **latitude eval-identical** post-dedup. Dead system76-scheduler `settings.*` removed (ignored under `useStockConfig=true`, official option docs).
- `modules/roles/default.nix` NEW aggregator, wired into mkHost (nix-media's explicit import dropped); `roles.media.ports` option (jellyfin 8096, audiobookshelf 13378, grafana 3001, cadvisor 8080, dockerMetrics 9323) consumed by docker.nix/monitoring.nix/caddy.nix — all evaluated outputs byte-identical to the old literals.
- nix-media: dead `useDHCP=true` (hw-config) removed + `mkForce false` → plain false (networkd unit set proven identical via HEAD worktree eval); duplicate configurationLimit removed.
- `hosts/yoga/home.nix`: persisted `.config/kitty/lucid-glass.conf` (Glass slider state reset each boot before).
- home/default.nix: GNOME-shell dconf pins gated `mkIf (!config.desktop.hyprland.enable)` (yoga dconf loses org/gnome/shell only; yoga-gnome eval-identical). btop → nord theme (ships with btop; was tomorrow-night — only HM file derivation that rebuilt). theme.nix comment fix, features import order alphabetized, mkHost stale allowUnfree comment fixed, caddy MagicDNS-zone comment, latitude NVIDIA dGPU comment (user: GPU present, deliberate). `.zcodeignore` staged.
- REPO_OVERVIEW.md synced (locale/openssh/hardware/roles/profile rows, mkHost step list, microcode gotcha row, ryzen-tdp 15/25/15 values).

Gotchas: statix flags repeated top-level keys in one attrset body (core/services/hardware ×N) — merge nested, it failed flake check twice. Flake lock moved mid-session (parallel session: 7c8764b→26f4107e) — baselines and post-evals both ran on the new lock, diffs still valid.

Pending: user switch → verify VT/LUKS prompt is QWERTZ, ssh password prompts rejected (key-only), Glass slider survives reboot. Related: [[desktop-switch-architecture-2026-10-13]], [[hyprland-lock-nooutputs-segv-2026-10-13]] (their staged changes share the index).
