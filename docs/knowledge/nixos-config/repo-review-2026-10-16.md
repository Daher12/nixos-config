---
name: repo-review-2026-10-16
description: Full read-only config review 2026-10-16 (plan mode) — report
  delivered, NOTHING applied; prioritized P1-P3 findings + verified non-issues
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a118bbb3-e357-4845-82b6-65be5bed79f3
---

Full 3-host config review requested as "report only, I'll decide what to apply" — report delivered 2026-10-16, no changes made. Verdict: repo in strong shape (flake hygiene, options discipline, no IFD, no deprecated options on pinned nixos-26.05). Explored via 3 parallel Explore agents + my own reads; option claims verified against search.nixos.org stable + fish docs.

**P1 findings (verified, tiny effort, not yet applied):**
1. Console/LUKS keymap `us` on non-GNOME hosts: `console.useXkbConfig=true` (core/locale.nix:10) but `xkb.layout=de` only inside desktop-gnome (mkIf-gated) → yoga + nix-media VT & LUKS prompt = us on German keyboards. Fix: move layout to core/locale.nix.
2. `profiles/laptop.nix:28-33` system76-scheduler `settings.*` = DEAD config — `useStockConfig=true` ignores `settings` (official option docs). Also only non-mkDefault lines in profile.
3. kitty lucid-glass.conf written at runtime, NOT persisted on yoga → Glass slider resets each boot. Fix: file entry in hosts/yoga/home.nix.
4. yoga: no uid pin for dk (impermanence host!) — latitude pins 1000, nix-media 1001. Pin after confirming live uid.
5. nix-media: dead `useDHCP=true` in hardware-configuration.nix (killed by mkForce) + configurationLimit=10 duplicate of core default.

**P2 (intent checks):** nix-media SSH `openFirewall=true` opens port 26 to whole LAN vs in-file "close global access" comment; latitude `nvidia-disable` likely on iGPU-only E7450 (needs lspci); stale mkHost.nix:41 allowUnfree comment; .zcodeignore untracked.

**P3 (judgment calls):** yoga↔latitude laptop-common dup (~60 lines: openssh mgmtLanCidr, nas/brave, nftables hardening "mirror of yoga's", TLP, zswap param, libva-utils) → profiles/laptop.nix; nix-media port literals repeated across modules; home/default.nix:33-41 GNOME dconf unconditional incl. on Hyprland yoga; ad-hoc session-kind flags + kitty hardcoded in lucid seed vs hyprland.terminal option; dead-option surface list (mountOptions, brave.originMode, core.networking.backend/dns, etc.); roles/ not aggregated; caddy.nix MagicDNS zone literal.

**Verified NON-issues (don't re-flag):** `services.journald.extraConfig` IS current form in 26.05 (no `settings` option exists, unlike logind); `zramSwap.swapDevices=1` = the default (harmless); fish history stays in `~/.local/share/fish/fish_history` incl. 4.x (XDG_STATE move never landed, fish-shell#9785) and yoga persists it — an Explore agent claimed a gap, disproved; accounts-daemon/xkb.layout/runAsRoot all still valid; unified `hardware.cpu.updateMicrocode` does NOT exist. api.key/.Trash-1000/documentation gitignored correctly.

Fleet facts: stateVersions yoga 25.11 / latitude 25.05 / nix-media 24.05; lix via `pkgs.lixPackageSets.latest` (no lix input; nix-media cppnix); yoga+latitude zen 7.2.9, nix-media default 6.18.55; home-manager release-26.05 follows nixpkgs. Related: [[update-sweep-plan-2026-10-16]] (same day, separate pin-sweep work).

**2026-10-16 follow-up — user decisions + approved-fix plan (ExitPlanMode DENIED, NOTHING executed; plan ready to re-run):**
- User answers: latitude DOES have an NVIDIA GPU → nvidia-disable is intentional, comment-only; yoga dk uid=1000 confirmed → pin it; console keymap fix as `de` ("preferred if no effort behind it — keep us otherwise"); nix-media SSH = deliberately LAN-wide, key-or-Tailscale-SSH only, never password (user corrected mid-turn).
- Plan scope (all P1+P2 + selected P3): xkb.layout mkDefault "de" → core/locale.nix (remove from desktop-gnome.nix); delete dead scheduler settings block (laptop profile); persist `.config/kitty/lucid-glass.conf` file entry; yoga uid 1000; delete nix-media dead useDHCP + dup configurationLimit (plain false, drop mkForce); `KbdInteractiveAuthentication = mkDefault false` in core/openssh.nix + fix misleading nix-media comment; mkHost.nix:41 comment; latitude nvidia comment; laptop dedup → profiles/laptop.nix (description, openssh block, nas, brave, nftables+comment, openFirewall=false — all mkDefault) — SKIPPED TLP pair + zswap param + libva-utils (list/attrs merge semantics make profile sharing fragile: mkDefault list/attrs loses wholesale to plain host defs); microcode — verify upstream default first (likely `enableRedistributableFirmware` → just delete 3 per-host lines; if false, per-vendor in hardware/default.nix — do NOT set both vendors true, intel microcode blob would bloat AMD closure); new modules/roles/default.nix aggregator wired into mkHost; `roles.media.ports` option (jellyfin 8096/audiobookshelf 13378/grafana 3001/cadvisor 8080/dockerMetrics 9323) consumed by docker/monitoring/caddy; dconf gated `!config.desktop.hyprland.enable` in home/default.nix; theme.nix comment, features/default.nix import order, caddy MagicDNS comment, btop nord (verify nord.theme ships first); REPO_OVERVIEW sync.
- NOT doing: dead-option pruning, journald core module, session-kind flag, lucid terminal single-sourcing.
- QC: eval-snapshot baselines (keymap/nftables/ssh settings/TLP/ucode/sysPkgs/grafana+jellyfin strings per host) — baseline evals were BLOCKED by plan mode, must take them pre-change; then nix fmt, git add new files, flake check, dry-build ×3 hosts, home-files byte-diff yoga. No commit/switch.
