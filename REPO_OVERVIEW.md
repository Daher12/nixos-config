# REPO OVERVIEW — Quick Reference for AI Models

This is the single-stop reference for understanding this NixOS configuration repository.

**Last updated:** 2026-11-14 | **NixOS version:** 26.05 "Yarara" | **Flake-based:** Yes

---

## What This Repo Is

A personal NixOS flake managing **3 hosts** (yoga, latitude, nix-media) with a modular architecture. Uses Home Manager, SOPS-nix secrets, Disko disk partitioning, and Btrfs impermanence.

---

## Hosts at a Glance

| Host | Hardware | Role | Special Features |
|------|----------|------|------------------|
| **yoga** | Lenovo Yoga 7 Slim Gen 8 (AMD Ryzen) | Primary laptop | Impermanence (root wiped), SecureBoot, LUKS, Btrfs, dual desktop (niri+Noctalia / GNOME attrs), virt-manager (Windows VM) |
| **latitude** | Dell E7450 (Intel) | Legacy laptop | Lix package mode, nvidia-disable, TLP power, Disko (LUKS + ext4), opencode |
| **nix-media** | Intel N100 Mini PC | Media server | Docker (Jellyfin, Silo trial, Audiobookshelf), Prometheus+Grafana, Caddy, NFS, systemd-networkd |

---

## Directory Structure — What Goes Where

```
├── flake.nix                  # ENTRY POINT: inputs, outputs, host definitions
├── flake.lock                 # Pinned input revisions
├── lib/
│   └── mkHost.nix             # Host builder function — how all hosts are constructed
├── modules/
│   ├── core/                  # Always-on: boot, nix, users, networking, locale, sysctl
│   ├── features/              # Optional: desktop, bluetooth, fonts, impermanence, VPN, VMs, etc.
│   ├── hardware/              # GPU drivers, KVM, TDP, nvidia-disable
│   └── roles/                 # Server roles (media server NFS)
├── profiles/                  # Role bundles applied via mkHost (laptop, desktop-gnome, desktop-niri)
├── hosts/
│   ├── yoga/                  # Host-specific: default.nix, disks.nix (disko), home.nix, opencode.nix (enable + persistence), yoga-s2h.nix (suspend-then-hibernate hook)
│   ├── latitude/              # Host-specific: default.nix, disks.nix (disko), hardware-configuration.nix (drivers only), home.nix
│   └── nix-media/             # Host-specific: default.nix, docker.nix, monitoring.nix, caddy.nix, maintenance.nix (auto-upgrade + weekly reboot, Result-probe guard), ntfy.nix + alertmanager-ntfy-bridge.py (push alerts, daily heartbeat), dashboards/, landing.html, hardware-configuration.nix
├── home/                      # Shared Home Manager: battery refresh, browsers, terminal, theme, git, opencode + opencode-skills/ (portable docx/pdf/pptx/xlsx skills), niri.nix (compositor KDL) + noctalia.nix (shell) + assets/fonts/ (vendored Google Sans Flex)
├── pkgs/                      # Custom packages: colloid-gtk, fluent-icons, zcode (AppImage), mikromcp, is-on-ac
├── secrets/                   # SOPS-encrypted per-host secrets (age keys)
├── tests/                     # 7 NixOS VM tests, run via `scripts/test-suite vm` (NOT part of `checks`)
├── docs/                      # opencode-migration.md (zcode→opencode checklist) + knowledge/ (agent-knowledge archive mirrored from ZCode memory by scripts/export-zcode-memory)
├── README.md                  # Fleet overview + operating commands (human entry point)
├── REPO_OVERVIEW.md           # This file
├── SOPS_RUNBOOK.md            # Secrets architecture, re-encryption/rotation procedures, troubleshooting
├── AGENTS.md                  # Rules for AI coding agents (conventions, QC workflow)
├── scripts/                   # install.sh (installer), update-safe (safe updater), test-suite (shared agent QC)
└── .github/workflows/         # CI: weekly flake updates + lint checks
```

---

## Module Architecture

### Core Modules (`modules/core/`) — Always included

| File | Purpose |
|------|---------|
| `audio.nix` | PipeWire audio, ALSA, PulseAudio, JACK, 48kHz clock |
| `boot.nix` | systemd-boot, Plymouth, `/tmp` tmpfs (no scheduler udev rule since 2026-10-24 — kernel defaults are `none`/NVMe and `mq-deadline`/SATA; the old rule forced `none` onto the SATA SSD) |
| `input.nix` | libinput input handling |
| `locale.nix` | Timezone, locale, German XKB layout (fleet-wide — console VTs + LUKS prompt derive their keymap from it via `useXkbConfig`; previously GNOME-only, which left yoga/nix-media consoles on `us`) |
| `networking.nix` | Base networking (NetworkManager, iwd, systemd-resolved) |
| `openssh.nix` | sshd with fleet-hardened defaults (PasswordAuthentication=no, KbdInteractiveAuthentication=no — key-only, never passwords, 2026-10-16 —, PermitRootLogin=no, UseDns=no); `mgmtLanCidr` emits the nftables SSH-from-management-LAN accept rule (yoga/latitude — nftables-only); `profiles/laptop.nix` enables it for the laptops |
| `nix.nix` | Flakes, caches (nixpkgs cache, cachix), GC, store optimization |
| `shell.nix` | zoxide shell integration |
| `sysctl.nix` | Kernel parameters |
| `systemd.nix` | systemd manager timeouts, coredump disabled |
| `users.nix` | Main user account, group membership; `core.users.authorizedKeys` writes declarative SSH pubkeys to `/etc/ssh/authorized_keys.d/$USER` (additive to `~/.ssh/authorized_keys`; set on nix-media + latitude since 2026-10-19) |

### Feature Modules (`modules/features/`) — Toggle on/off per host

| File | Purpose |
|------|---------|
| `desktop-gnome.nix` | GNOME 50, GDM, dconf, XDG portals |
| `desktop-niri.nix` | niri desktop (`features.desktop-niri.enable`; attr `yoga` + `profiles/desktop-niri.nix`): `programs.niri` (nixpkgs module — session entry `niri`, gnome-keyring, portals via xdg-desktop-portal-gnome; niri 26.04's native systemd session needs NO uwsm: `niri-session` → `niri.service` `BindsTo=graphical-session.target`), noctalia-greeter (`services.displayManager.noctalia-greeter` from the `noctalia-greeter` flake input's NixOS module, imported ONCE here — importing the same flake-module attrset from two repo modules does NOT dedupe, fresh module identity per evaluation, option declarations collide; greetd-backed with its own bundled wlroots compositor, `session.default = "Niri"`, de/nodeadkeys keymap, Posy cursor, `passwordless-sync-users` polkit rule so the shell syncs wallpaper/palette to the greeter without a prompt), optional greetd autologin (`greeter.autoLogin`, default true on the profile — `services.greetd.settings.initial_session` wired directly because the upstream greeter module does not translate `services.displayManager.autoLogin`; fires only at boot, after logout greetd falls back to the greeter; the HM `noctalia-lock-at-boot` oneshot locks the fresh session so auth moves to the Noctalia lock screen — `After=graphical-session.target` is load-bearing, see Known Gotchas), PAM greetd/login keyring (the Noctalia lock screen hardcodes PAM `login`), gvfs + GTK apps + `xwayland-satellite` (niri ≥25.08 spawns it from PATH on demand — without the package X11 clients fail to open), upower. No polkit agent or cliphist package: Noctalia ships both functions. HM side: `home/niri.nix` + `home/noctalia.nix` (the shell is a home-manager user service, no NixOS shell module); battery-refresh runs its niri backend (`niri msg`, selected off `desktop.niri.enable`) — the panel mode in `home/niri.nix` is resolution-only (`mode "3072x1920"`: niri picks the highest rate for it; an omitted mode would take the EDID-preferred 60 Hz). Mutually exclusive with `desktop-gnome` (assertions in both feature modules) |
| `bluetooth.nix` | BlueZ stack |
| `brave.nix` | Managed Brave policies → `/etc/brave/policies/managed/origin.json` (`features.brave.enable`, on yoga+latitude): Origin mode flip (`BraveOriginFeatureEnabled`, free on Linux) + debloat list; supersedes the former hand-maintained `bloat.json` at the same path (its impermanence entry was removed 2026-10-04) |
| `fonts.nix` | Font packages, fontconfig |
| `impermanence.nix` | Btrfs root wipe on boot, persist to `/persist` |
| `litellm.nix` | LiteLLM OpenAI-compatible gateway (loopback by default, `listenAddress` to expose; ON on nix-media at 0.0.0.0 behind trusted tailscale0 — config via sops `litellm_config` side file, see module header) |
| `mnamer.nix` | mnamer media renaming tooling (feature options + `mnamer-tools` wrapper; consumed by nix-media). `extraIgnore` appends host-specific patterns to the module's default `ignore` set — hosts no longer restate the defaults |
| `secureboot.nix` | Lanzaboote Secure Boot |
| `sops.nix` | SOPS-nix secret decryption |
| `spotify.nix` | Spotify desktop client patched with SpotX (ad blocking) at build time (`features.spotify.enable`, laptops via `profiles/laptop.nix`): consumes the overlay-only `spotx-nix` flake input (no NixOS/HM module upstream) inside `mkIf` — disabled hosts never evaluate `spotify-spotx`; `spotxArgs` option passes extra SpotX-Bash flags; `nativeWayland` (default true) wraps `bin/spotify` to set `NIXOS_OZONE_WL=1` scoped to the app — the client is CEF/Chromium and otherwise sits under XWayland at 1x (tiny UI, oversized cursor on scale-2 outputs; QT_* vars are no-ops, and a hardcoded scale factor would double-scale under GNOME) — the nixpkgs wrapper's hook then unsets `DISPLAY` so it runs native Wayland with the compositor's scale; state persisted on yoga as `~/.config/spotify` |
| `virtualization.nix` | QEMU/KVM, libvirt, virt-manager, SPICE USB redirection, per-guest launchers/DHCP reservations (`features.virtualization.guests`), optional virtio-win ISO at `/var/lib/libvirt/images/virtio-win.iso` (`features.virtualization.virtioWinIso`, off by default since 2026-10-24 — it pinned ~700 MB into every generation and is only needed during a Windows install), self-healing default-network unit, libvirt firewall backend pinned to iptables + scoped virbr0 DHCP/DNS input rules (see Known Gotchas) |
| `vpn.nix` | Tailscale mesh VPN |
| `power-tlp.nix` | TLP power management |
| `kernel.nix` | Kernel variant (zen) |
| `oomd.nix` | systemd-oomd |
| `zram.nix` | ZRAM swap |
| `nas.nix` | NFS/SMB mounts (Tailscale) |
| `onlyoffice.nix` | OnlyOffice integration — the app's .desktop wrap injects `XCURSOR_SIZE=cursorSize` (64 on yoga) per app; never exported globally since 2026-10-18, because uwsm's env preloader sources /etc/profile last and a global export beat theme.nix's HM-level 32 at boot (the oversized cursor on the reboot lock screen) |
| `filesystem.nix` | Btrfs scrub/balance, ext4 tuning |
| `network-optimization.nix` | BBR, buffer tuning |

### Hardware Modules (`modules/hardware/`) — Device-specific

| File | Purpose |
|------|---------|
| `default.nix` | `hardware.isPhysical` gate: fwupd + redistributable firmware + per-vendor `updateMicrocode` (mkDefault true, both vendors — upstream default is plain `false`; moved from the host files 2026-10-17, wrong-vendor ucode blob is inert) |
| `amd-gpu.nix` | AMD GPU + VA-API |
| `intel-gpu.nix` | Intel GPU (VPL, OpenCL, GuC) — used by nix-media |
| `amd-kvm.nix` | AMD KVM module |
| `nvidia-disable.nix` | Disable discrete NVIDIA (latitude — this unit's E7450 has the optional dGPU, deliberate) |
| `ryzen-tdp.nix` | AMD Ryzen TDP limits (AC/battery profiles via the shared `pkgs/is-on-ac` probe) |

### Profiles (`profiles/`) — Pre-built role bundles

| File | Includes |
|------|----------|
| `laptop.nix` | bluetooth, TLP, zram, network-optimization, zen kernel, oomd, SecureBoot, Tailscale, system76-scheduler (stock config — its `settings.*` are documented as ignored under `useStockConfig`, so none are set), `pkgs.libva-utils` (lifted from both host files 2026-10-19). Fleet laptop baseline moved here from the host files 2026-10-17: `core.users.description`, `core.openssh` (mgmt-LAN SSH), `features.nas`/`features.brave`/`features.spotify` enables, nftables firewall hardening comment + `openssh.openFirewall = false` |
| `desktop-gnome.nix` | GNOME desktop, fonts |
| `desktop-niri.nix` | niri + Noctalia desktop, fonts + `greeter.autoLogin` |

---

## How Hosts Are Built

`lib/mkHost.nix` is the host builder. Every host is defined in `flake.nix` like (all `mkHost` options shown; `profiles`, `withHardware` and `lix` have defaults — e.g. yoga omits `lix`, which defaults to `true`):

```nix
nixosConfigurations.yoga = mkHost {
  hostname = "yoga";
  mainUser = "dk";
  profiles = [ "laptop" "desktop-niri" ];  # yoga-gnome attr = same host with "desktop-gnome"
  withHardware = true;
  lix = true;  # true → Lix from nixpkgs (cached), false → CppNix
  hmModules = [ ... ];
  extraModules = [ ... ];
};
```

**Desktop switching (yoga):** `yoga` (niri + Noctalia + noctalia-greeter — the daily driver, promoted from the former `yoga-niri` attr 2026-11-14) and `yoga-gnome` (GNOME + GDM, the backup DE) are the same machine with different desktop profiles — `features.desktop-niri` and `features.desktop-gnome` assert against each other. Switch desktops by rebuilding the other attr (`nus yoga-gnome switch` / `nus yoga switch`); no config edits. The retired Hyprland + Lucid + DankGreeter stack lives on the `archive/hyprland-lucid` branch (DMS testbed: `dux-shell` branch).

`mkHost` applies:
1. Core modules (always)
2. Feature modules (always, but toggled via `mkIf`)
3. Role modules (`modules/roles`, always imported — `roles.media` is enabled per host; also carries `roles.media.ports`, the fleet media-stack port single source)
4. Hardware modules (if `withHardware = true`)
5. Profile modules
6. Infrastructure: sops-nix, home-manager, disko
7. nixpkgs config with overlays (colloid, fluent, zcode, mikromcp, is-on-ac; a second overlay disables `python313Packages.fastmcp`'s test suite — dep of `mcp-nixos`; its concurrency tests broke on the 2026-10-31 nixpkgs bump. The former quickshell/dms-greeter overlay stage died with the Hyprland stack 2026-11-14)
8. Traceability: `system.configurationRevision = self.rev or self.dirtyRev or null` (added 2026-10-19 — `nixos-version --configuration-revision` then answers which commit a running system was built from)

---

## Home Manager (`home/`)

Shared across all hosts via `home/default.nix`:

| File | Purpose |
|------|---------|
| `default.nix` | Entry point, session vars (`EDITOR=ox`), GNOME-shell extension dconf pins (gated off on the niri session since 2026-10-17) |
| `battery-refresh.nix` | Panel refresh-rate switch on battery (`desktop.battery-refresh.*`) — a `systemd.user.services.battery-refresh` bound to `graphical-session.target` in every session (niri: `niri msg output … mode`, picked first by an explicit niri > GNOME selector; GNOME: `gnome-monitor-config`); also home of the shared `desktop.monitors` option (formerly `desktop.hyprland.monitors` — the session-independent panel definition hosts/yoga/home.nix sets once for every attr, read by `home/niri.nix` for its output block and by this daemon for its AC/battery modes; the assertion enforcing an explicit WxH@Hz entry lives right next to it); AC/battery detection via the shared `pkgs/is-on-ac` probe; since 2026-10-24 the daemon also probes the panel's actual Hz each poll (`niri msg -j outputs` — `current_mode` index, `refresh_rate` in millihertz / `gnome-monitor-config list`) and re-applies on mismatch — hibernate resume used to leave the panel stuck at 120 Hz on battery. niri spells its apply modes per compositor grammar (matches EDID strings exactly, three decimals) — the shared loop takes them as `acMode`/`batMode` parameters since 2026-11-07 |
| `browsers.nix` | Firefox + Brave with managed extensions (Firefox: uBlock Origin + Bitwarden; Brave: CNL Decryptor), policies. Firefox is the pinned default browser via `xdg.mimeApps` (store-symlinked `mimeapps.list` — runtime write attempts by Brave fail; changing the default = flake edit; yoga's zcode deep-link handler is folded in via `hosts/yoga/home.nix`). Brave launches with `--password-store=basic` (deliberate: keyring not reliably unlocked before the browser under autologin) and `--no-default-browser-check`; system-side policies in `modules/features/brave.nix` |
| `terminal.nix` | Terminals split per stack (2026-11-08: the foot trial won, kitty LEFT the niri attr): **foot is the terminal of the niri/Noctalia attr** (`programs.foot`, gated on `desktop.niri.enable` — `foot.ini` via HM settings, foot-server unit for instant `footclient` windows; Rosé Pine main palette verbatim, CaskaydiaCove Nerd Font Mono 11, `dpi-aware=no` (logical-pt sizing at scale 2), foot draws opaque and is frosted compositor-side by the niri window rule — foot 1.27 keys: `[colors-dark]` palette + `alpha`, `cursor = <text> <block>`, strict RRGGBB — validate with `foot --check-config`, never from memory); **kitty stays the terminal of the GNOME hosts** (`programs.kitty` gated on `!desktop.niri.enable`: static dark palette — kitty never follows light/dark (2026-09-30); Nord via `themeFile`, `background_opacity` 0.93 — mutter has no blur (the dormant Rosé Pine/noctalia branches were removed 2026-11-08, the lucid Glass include died with the stack 2026-11-14); `--single-instance` symlinkJoin wrap — first launch pays full startup cost, later launches attach to the running instance; the dormant ghostty options were removed 2026-11-14 — kitty won the slot 2026-09-27 and ghostty was never re-flipped), Fish shell (hydro, fzf-fish) + the `nus` wrapper (`programs.fish.functions.nus` — moved here from hosts/yoga/home.nix 2026-10-19 so both laptops have it), fzf colors per palette via the `fzfColors` role map (Rosé Pine on the noctalia attr: iris accents, gold marker, rose hl+; Nord single-accent elsewhere), btop (nord theme elsewhere — ships with btop; on the niri attr `color_theme` takes the vendored upstream `rose-pine/btop` theme via `pkgs.writeText` + full path, since btop 1.4.8 ships no rose-pine), bat stays Nord (bat 0.26.1 ships no Rose Pine theme), fastfetch.minimal, CLI tools |
| `theme.nix` | Colloid GTK (Nord), Fluent icons, Posy cursors, `switch-theme` script (runtime owns `~/.config/gtk-4.0` via the colloid symlink farm — the former lucid/DMS skip branch died with the stack 2026-11-14), darkman (off on the noctalia attr — the shell owns day/night GTK switching) |
| `niri.nix` | niri session config (`desktop.niri.enable`): hand-written KDL deployed to `~/.config/niri/config.kdl` through a build-time `niri validate -c` runCommand gate (broken config fails the rebuild, not first login). Binds mirror the Hyprland muscle memory (SUPER+T/Q/R/P/L/TAB/N/M/comma, workspaces SUPER+N focus + SUPER+SHIFT+N move, XF86 keys with the 10% brightness steps); shell surfaces go through Noctalia IPC (`noctalia msg panel-toggle launcher|session|clipboard|control-center notifications`, `session lock`, `settings-toggle`; ALT+TAB = `window-switcher hold`). Fully static — no shell-written include fragments (the DMS-era `dms/*.kdl` includes are gone). Noctalia glue per the upstream niri recipe: `debug { honor-xdg-activation-with-invalid-serial }` (notification actions/window activation), float rule for the settings window (`dev.noctalia.Noctalia`, 1080x920), `layer-rule` placing `^noctalia-backdrop` within the overview backdrop (blurred overview, pairs with `backdrop.enabled` in `home/noctalia.nix`), compositor blur on the shell surfaces + the window switcher (`background-effect { blur true; xray false }`, backed by the global `blur` node mirroring the Hyprland frost: passes 2, offset 5, noise 0.04, saturation 1.0). No `Mod+Shift+Slash` bind: on the de layout niri also fires it as Mod+Shift+7. No clipboard-watcher autostart (Noctalia keeps its own history). Panel scale from the shared `desktop.monitors` list (home/battery-refresh.nix); active-only focus ring (Rosé Pine iris `#c4a7e7` on the focused window, inactive transparent — the shell palette), 12px gaps, 16px corner radius, Hyprland float rules (FileRoller/Loupe/Bitwarden/Firefox PiP) as app-id window rules. Window-open policy: a global `open-maximized true` rule opens every window as a maximized COLUMN (full working area minus struts and gaps — never edge-to-edge) with `open-maximized-to-edges false` kept alongside (a granted client xdg-maximize request = niri's maximize-to-edges state, genuinely edge-to-edge bar-only, which is what Firefox/ZCode restore from their profiles); foot/footclient are the exception (`open-maximized false` → the layout default-column-width 0.5, half width; APP-ID TRAP: Mod+T footclient windows report app-id `footclient`, direct `foot` runs `foot` — match both or they silently miss the rule), SUPER+SHIFT+F = `maximize-column` toggle (SUPER+F stays fullscreen — niri's defaults have the pair swapped). Mod+Ctrl+F = `maximize-window-to-edges` toggle (niri's default Mod+M is btop here); zcode (Electron) self-maximizes AFTER mapping and niri grants post-map maximize requests unconditionally (`src/handlers/xdg_shell.rs` — the map-time deny rule can't catch it), so the desktop entry routes through the `zcode-unmax` wrapper (home/niri.nix) which waits for the new window to reach the to-edges state and trades it for a maximized column — proven live 2026-11-07. Terminal frost IS rule-forced: kitty (trial era) spoke ext-background-effect itself but client-requested blur rendered focus-asymmetric (pixel-proven: the xray backdrop sampling is focus-keyed in niri 26.04, upstream-quirk, terminal-agnostic), so foot — the terminal of this attr since 2026-11-08, kitty removed — draws fully opaque and the rule sets `opacity 0.75` + `background-effect { blur true; xray true }` on `^(foot|footclient)$` (rule-forced `xray false` rendered the FOCUSED window fully opaque — never force blur without xray). Motion: Lucid-parity window open/close (220ms/150ms ease-out) + softened niri springs (damping-ratio 0.9, stiffness 400) on workspace-switch/window-movement/horizontal-view-movement, eased resize and `overview-open-close` (150–250ms), `overview { zoom 0.9 }` for bigger tiles in the blurred overview |
| `noctalia.nix` | Noctalia shell v5 (`desktop.noctalia.enable`, pushed on by `features.desktop-niri`): imports the `noctalia` flake input's `homeModules.default` (`programs.noctalia` — package from the input's own cachix-backed build, `noctalia.service` on `graphical-session.target`, declarative `~/.config/noctalia/config.toml` as a store symlink behind the build-time `noctalia config validate` gate — never disable `checkConfig`). Layered config: GUI edits land in `~/.local/state/noctalia/settings.toml` and WIN over the Nix baseline (persisted; harvest with `noctalia config export merged`). Layer-of-record harvests: 2026-11-08 (full state strip, backup `settings.toml.bak-2026-11-08`) and 2026-11-15 (second drift harvested into nix, commit `7ffd2ac`; its state strip lands only AFTER the switch that deploys it — deleting `settings.toml` while the shell runs makes it file-watch reload the CURRENT generation's baseline, live-observed 2026-11-15). Theme (2026-11-15 harvest): palette follows the WALLPAPER — `source = "wallpaper"` + M3 `wallpaper_scheme = "m3-content"` (Material-3 tonal extraction from the current wallpaper, re-themes on wallpaper change), fixed `dark` (sun-schedule auto gone), fallbacks community palette `Tomorrow` / builtin `Nord` — supersedes the 2026-11-06/08 Rosé Pine + `faithful` + `auto` era; `theme.templates.enable_builtin_templates = false` (GUI choice — GTK theming is owned by home/theme.nix's adw-gtk3 pin, btop by home/terminal.nix; the `niri`/`kitty` ids stay off regardless — both would rewrite Nix-owned files), `backdrop.enabled` (blurred niri overview), lucid-look shell port: Google Sans Flex (TTF vendored at `home/assets/fonts/` since 2026-11-14 — originally borrowed from the retired lucid input, ~/.local/share/fonts/noctalia/), Rosé Pine builtin palette in auto mode applied to apps via the shell's `gtk3`/`gtk4` templates (noctalia.css into gtk.css + gsettings adw-gtk3(-dark); `adw-gtk3` in desktop-niri systemPackages — the template skips silently when the theme is missing; `niri`/`kitty` template ids must STAY off — both rewrite Nix-owned files; darkman off on this attr — the shell owns day/night GTK switching; `settings.ini` stays HM-owned with a matching adw-gtk3-dark pin, home/theme.nix), ONE bar surface in capsule mode with explicit `capsule_group` left/center/right (three named bars would stack on the layer-shell top edge); GUI-tuned geometry harvested 2026-11-08: thickness 28, margins 5/20, strip `background_opacity 0.59` (the strip itself carries the frost via its client blur regions), pill fills at `capsule_opacity 0`, `scale 1.05`, `font_scale 0.9; workspaces widget in `minimal` style with empty workspaces hidden, `[widget.workspaces]` plus per-widget trims (`network`/`volume` label-less, volume scale 0.9), desktop widget cards off, short notification history (3h, overlay, max 2), slow monitor polling dock DISABLED by harvested live choice 2026-11-07 (geometry kept for a GUI re-enable), `glass` panels, `shell.lang = "de"` (upstream `de.json` catalog — no patch layer), `shell.animation.speed = 0.8` (re-tuned 2026-11-15; was 1.15), fade-only lock/wallpaper transitions (schema default picks from a fancy wipe/disc/stripes list at 1500ms), lockscreen widget layout (big clock + compact 400px password capsule — `box_width` pinned because the compact cap only applies when it is 0; no per-widget scale exists in v5.4.1, desktop widgets included), built-in polkit agent (`shell.polkit_agent`), direct-fork app launches (`launch_apps_as_systemd_services = false`, instant) + `systemd.user.services.noctalia.Service.KillMode = "process"` — HM's X-Restart-Triggers restart the unit on every config change, and the default control-group KillMode killed every launched app at each switch, wallpapers from `~/Bilder/wallpapers` (user paths only — a store path dies at GC), night light 4500K, ENERGY timeline (2026-11-08 user spec; all inhibitor-aware): `idle.pre_action_fade_seconds = 0` — the 2s fullscreen Idle Dim fires before EVERY behavior incl. custom actions (live-probed), so it is off; idle behaviors `kbd-off` 60s (custom action: zero `platform::kbd_backlight` via brightnessctl, saving the level — double-fire safe — and `resume_command` restores it unless `msg status` reports locked) / `lock` 300s with 5s passwordless `lockscreen.grace_period_seconds` / `screen-off` 330s / `suspend` 1500s `lock_and_suspend` (battery baseline), plus `hooks` (TOML keys snake_case): `started`/`battery_charging`/`battery_discharging` all run one probe script that `noctalia msg config-set`s the suspend timeout to 5400 on AC — the 25 min battery / 90 min AC split; config-set persists that one key into the state layer (accepted trade-off, `started` re-derives it at every shell start), `session_locked` → kbd light off, `session_unlocked` → restore; the suspend→hibernate second stage remains hosts/yoga/yoga-s2h.nix (pure system-sleep hook, fires on this idle suspend like on any other), `lockscreen.lock_before_suspend`. NOTE: the GUI state layer (`~/.local/state/noctalia/settings.toml`, persisted since 2026-09) still WINS per-key over this config.toml — after a fresh-boot divergence, reconcile with `noctalia config export merged` |
| `git.nix` | Git config (delta, SSH, rebase on pull) |
| `opencode.nix` | Shared opencode config (models, providers, permissions, MCP, libstdc++ wrap) — opt-in per host via `opencode.enable = true`; impermanence persistence stays in the host files (`hosts/yoga/opencode.nix`). Since 2026-11-01 also deploys the portable document skills (`home/opencode-skills/` docx/pdf/pptx/xlsx → `~/.config/opencode/skills/`, ZCode citation sections stripped — see `docs/opencode-migration.md`), exposes `glm-5.3` (high) on the zai-coding-plan provider, and carries the bash allowlist curated from the ZCode ruleset export (frequency-ranked read-only + build-gate commands; `nix flake update`, sops, switch/boot and `test-suite vm/full` stay ask-gated) |

Host-specific home additions go in `hosts/<name>/home.nix`.

---

## Secrets (SOPS)

- **Config:** `.sops.yaml` — every file encrypted to the operator key + the host's own identity
- **Secrets:** `secrets/hosts/{yoga,latitude,nix-media,nix-media-litellm}.yaml` (`dk_password_hash` is load-bearing on every host — modules/core/users.nix; the litellm sidecar exists because `nix-media.yaml` is still encrypted to the retired admin key — new nix-media secrets go into side files until the SOPS_RUNBOOK.md §3 re-encryption)
- **Usage:** Imported via `modules/features/sops.nix`, accessed as `config.sops.secrets.<name>.path`
- **Operator key:** `age1ff0ly0tej0yk39ycfq0dz0skmvqhe3tzuhdyaq2hkl52enu68sqqrr90s2` (private on yoga, `~/.config/sops/age/keys.txt`)
- **Host identities:** yoga = ssh-derived (`method = "ssh"`, no key.txt — identity is the persisted SSH host key); latitude + nix-media = classic `key.txt` on-device
- **Full reference:** `SOPS_RUNBOOK.md` (editing, re-encryption, rotation, troubleshooting)

---

## CI/CD (`.github/workflows/`)

- **`ci.yml` — push/PR gate (since 2026-10-19):** `nix flake check` (statix, deadnix, nixfmt) + dry-run build of every host. Hand edits are verified before they reach the fleet; the weekly cron alone validated nothing between bumps.
- **`bump.yml` — weekly input bump:** Trigger: weekly cron (Saturday 02:00 UTC — ahead of the Sunday nix-media reboot, so the fleet burns in a bumped closure on the daily drivers first) + manual dispatch. Actions: Update safe flake inputs → format with `nixfmt` → `nix flake check` → dry-run build every host → auto-commit (message carries `[skip ci]` so the push gate doesn't re-run the identical verification; `cancel-in-progress` off — the cron must never kill a long manual `include_lanzaboote` run). Checks: `statix`, `deadnix`, `nixfmt` (in `flake.nix`)

---

## Custom Packages (`pkgs/`)

| File | Package | Notes |
|------|---------|-------|
| `colloid-gtk-theme.nix` | Colloid GTK | Git main for GNOME 50 support; nixpkgs version outdated |
| `fluent-icon-theme.nix` | Fluent icons | Git main; nixpkgs version outdated |
| `zcode.nix` | ZCode | AppImage wrapper via `appimageTools.wrapType2`, pinned release |
| `mikromcp.nix` | MikroMCP | Fixed nix package for the MikroTik MCP server (no npx/network at runtime) |
| `is-on-ac.nix` | is-on-ac | AC-power probe (exit 0 = AC, 1 = battery) shared by the two power scripts that used to carry a copy-pasted `is_on_ac()` shell function: `home/battery-refresh.nix` + `modules/hardware/ryzen-tdp.nix` (added 2026-10-19) |

---

## Scripts

| File | Purpose |
|------|---------|
| `scripts/install.sh` | Host-agnostic NixOS installer: Disko, Btrfs snapshot, SSH key restore |
| `scripts/update-safe` | Safe update pipeline: pull, update inputs, lint, build, optional deploy |
| `scripts/test-suite` | Shared verification suite for all agents: `fast` (flake checks + dry-builds), `vm` (QEMU battery), `full`, `suggest` (changed-files → covering tests) |
| `scripts/export-zcode-memory` | Mirrors the ZCode auto-memory archive (`~/.zcode/cli/memories/projects/*/memory/`) into `docs/knowledge/<project>/` (hash suffix stripped); `--check` reports drift, every run secret-scans the result |

### `install.sh` — Host-Agnostic Installer

```bash
bash scripts/install.sh <host>    # host is required: yoga, latitude, nix-media
```

The script detects host features by **flake-evaluating the pinned clone**
(`features.impermanence.enable`, `/persist` presence in `config.fileSystems`,
`disko.devices.disk != {}`, `features.sops.enable`/`.method`,
`features.secureboot.enable`) — NOT by grepping source. Reason: nixfmt's
multiline formatting once silently broke grep-based impermanence detection,
which would reinstall yoga without the `@blank` template → initrd emergency
shell on every boot.

- **Disko**: any `disko.devices.disk` → disko destroy,format,mount (pinned rev from flake.lock)
- **Impermanence**: creates the `@blank` snapshot (template dirs validated by the rollback script)
- **Credentials**: passwords are declarative from sops — `dk_password_hash` in
  `secrets/hosts/<host>.yaml` applies at FIRST boot (nothing is set at install
  time). The installer provisions the sops **identity**: method=ssh (yoga) uses
  the restored SSH host key; method=age (latitude, nix-media) restores
  `<backup>/sops/key.txt` or generates a fresh key at `/var/lib/sops-nix/key.txt`.
  It then cross-checks the identity's derived age pubkey against the pinned
  yaml's `.sops.age` recipients and, on mismatch, prints the runbook fix steps
  (fresh keys are never recipients yet — expected on first enrolment).
- **Persist paths**: `/persist` in fileSystems → state restored to `/mnt/persist/system`, else `/mnt`
- **User uid/gid**: evaluated from the pinned config (`users.users.<user>.uid`, `.group`, `users.groups.<group>.gid`) — nix-media pins dk to 1001/982 (NFS anon mapping). When the group gid is unpinned (yoga/latitude — allocated at first boot), only the uid is chowned and the backup's group ownership survives

Flow: clone (pinned commit) → eval features → (optional Disko) → (optional @blank) → state restoration (SSH host keys, machine-id, sops identity, user data) → `nixos-install` → verification (bootloader; sops identity/recipient status — accounts lock at first boot if the identity chain is broken; GDM autologin still grants the desktop, sudo does not work until fixed)

### `update-safe` — Safe Update Pipeline

```bash
./scripts/update-safe <host> [build-only|test|boot|switch] [--pin <input>]... [--push]
```

Steps:
0. Pre-flight: refuses to start if `flake.lock` is dirty (an uncommitted lock from a previous run would collide with the next CI bump on nix-media's daily pull — hourly retry + ntfy spam)
1. `git pull --ff-only` — fast-forward only, no merge
2. `nix flake update` — updates nixpkgs, nixos-hardware, home-manager, sops-nix, disko, impermanence, preload-ng (+ every input named by `--pin`)
3. `nix flake check --impure --keep-going` — runs statix, deadnix, nixfmt checks
4. `nix build` — builds the host's toplevel derivation
5. Commits the updated `flake.lock` (pathspec-limited to that one file — other staged work in the tree is never swept in)
6. Optionally activates: `test` (temporary), `boot` (next boot), `switch` (live)
7. `--push` publishes the commit — without it, push manually; nix-media's daily `git pull --ff-only` only sees the bump once it is on main

Safe inputs are updated; locked inputs (lanzaboote, opencode, spotx-nix, noctalia, noctalia-greeter) are NOT updated by default. `--pin <input>` (repeatable) opts a pin into this run's update — e.g. `update-safe yoga boot --pin noctalia --pin noctalia-greeter` (since 2026-10-19). The former lucid refusal guard died with the lucid input 2026-11-14.

### `test-suite` — Shared Verification Suite (added 2026-11-01)

One entry point for ALL agents (zcode, opencode, humans — protocol in AGENTS.md § Verification workflow (QC)):

```bash
./scripts/test-suite fast [host...]   # flake checks (statix/deadnix/nixfmt) + dry-builds; standing gate, no confirmation
./scripts/test-suite vm [name...]     # the 7-test QEMU battery (≈5–15 min each); agents must ask the user first
./scripts/test-suite full [host...]   # fast + vm
./scripts/test-suite suggest          # map changed files → covering VM tests + cost/recommendation
```

The seven tests (`nix build .#nixosTests.x86_64-linux.<name>` still works — the runner just wraps it): `litellm-gateway`, `ssh-firewall` (both `tests/litellm-firewall.nix`), `virbr0-firewall`, `zram-heal`, `yoga-s2h-logic`, `nix-media-upgrade-pipeline`, `host-units-smoke`. All import the REAL modules under test (only `sops-stub.nix` is a stub); `ssh-firewall` has imported `modules/core/openssh.nix` directly since 2026-11-01 (previously restated the nft rule inline and could drift). `suggest`'s mapping table lives in the script — keep it in sync when adding a test.

---

## Manual Pins & Manual Packages

Five flake inputs are deliberately **held back** — `scripts/update-safe` (without an explicit `--pin`) and the CI weekly bump never touch them. Each moves only on purpose, with the procedure below. (The former lucid/quickshell/dank-greeter/dux-shell desktop pins died with the Hyprland stack 2026-11-14 — their histories live on `archive/hyprland-lucid`.)

| Input | Pinned to | Why held | Bump procedure |
|---|---|---|---|
| `noctalia` | tag `v5.4.1` | The session shell on yoga — no upstream binary cache without follows, so its own nixpkgs rides along (second nixpkgs eval) | `nix flake update noctalia` together with noctalia-greeter (paired), then smoke-test shell AND greeter |
| `noctalia-greeter` | tag `v1.7.0` | Paired greetd greeter (own bundled wlroots compositor) | `nix flake update noctalia-greeter` together with noctalia (paired), then smoke-test greeter AND shell |
| `spotx-nix` | default-branch pin (@ `070132b6`, SpotX-Bash `d145b19`) | Follows our nixpkgs, but its SpotX-Bash patch script must match nixpkgs' spotify version | Only on failure: if `spotify-spotx` fails with `Nixpkgs Spotify X is newer than SpotX-Bash Y` after a nixpkgs bump → `nix flake update spotx-nix` (see Known Gotchas) |
| `opencode` | tag `v2.2.4` | Still needs its own nixpkgs-unstable (bun 1.4.2 — nixos-26.05's bun hangs the build); v2.0.28–v2.1.3 were unbuildable from the upstream flake (src fileset missed `../script`, fixed 2026-10-19), and v2.2.5–v2.2.7 are skipped (vendored node_modules hash mismatches the shipped lockfile — upstream packaging bug, caught by the gate 2026-10-31 and re-tried 2026-11-12) — **gate every tag bump with `nix build github:anomalyco/opencode/<tag>` before editing flake.nix** | Edit the tag in `flake.nix`, then `nix flake update opencode`; find newest tag via `git ls-remote --tags https://github.com/anomalyco/opencode 'v2.*'`; full rationale in the flake.nix comment |
| `lanzaboote` | tag `v1.2.0` | Owns Secure Boot (lanzaboote-tool runs every boot) — never routine | CI `workflow_dispatch` with `include_lanzaboote: true`, or explicit manual bump + Secure Boot smoke test |

**Manual package (not a flake input):** `pkgs/mikromcp.nix` — npm tarball pinned by version + hash, with a vendored `pkgs/mikromcp-package-lock.json` injected before `buildNpmPackage` (the registry tarball ships no lockfile). Bump = edit `version`, the `src` hash, `npmDepsHash` and re-vendor the lockfile from the matching repo tag (the repo stopped tagging after v1.9.0 — take the lockfile from npm's `gitHead` commit, e.g. via raw.githubusercontent). Nothing automatic touches it.

---

## Key Patterns to Follow

1. **Adding a new host:** Create `hosts/<name>/default.nix` + `home.nix` + `hardware-configuration.nix`, add to `flake.nix` outputs via `mkHost`.

2. **Adding a feature module:** Create `modules/features/<name>.nix`, import it in `modules/features/default.nix`, toggle per-host via `mkIf`.

3. **Adding a custom package:** Create `pkgs/<name>.nix`, add it to the overlay in `flake.nix` (`colloidFluentOverlays`), and consume via `pkgs.<name>` in home-manager or system packages.

4. **Secrets:** Add to `secrets/hosts/<host>.yaml` via `sops secrets`, reference in modules via `config.sops.secrets.<name>.path`.

5. **Impermanence:** Add persistent directories to `hosts/<host>/home.nix` under `home.persistence."/persist".directories`.

---

## Common Commands

```bash
# Build and switch
sudo nixos-rebuild switch --flake .#$(hostname)

# Update inputs
nix flake update

# Lint and check (pass files explicitly — bare `nix fmt` fails)
nix fmt <changed-files> && nix flake check

# Safe update (full pipeline)
./scripts/update-safe yoga switch

# Shared verification suite (fast = lint + dry-builds, vm = QEMU battery)
./scripts/test-suite fast
./scripts/test-suite suggest

# Fresh install
bash scripts/install.sh yoga
```

---

## Impermanence — How It Works (yoga only)

The root filesystem uses **split Btrfs subvolumes**:

```
Btrfs top-level (subvolid=5)
├── @           → mounted at /      — wiped on every boot
├── @blank      → template snapshot — read-only, never mounted
├── @nix        → mounted at /nix   — persistent
└── @persist    → mounted at /persist — persistent
```

**Boot sequence:**
1. `@blank` validated (exists, read-only, has required mount-point dirs)
2. `@` recursively deleted
3. Fresh read-write snapshot created from `@blank` → `@`
4. Persistent subvolumes (`/nix`, `/persist`) mounted on top
5. Impermanence module bind-mounts persist entries to their target paths under `/`

All persistent data lives on `/persist`. The `@` subvolume contains only the NixOS skeleton (symlinks into `/nix/store`, mount-point dirs, `/etc` files from `environment.persistence`).

**Required `@blank` directories:** `nix persist boot home etc tmp var var/log var/lib var/lib/sops-nix var/lib/sbctl`

**Two persistence scopes:**
- `/persist/system` — system state: service data (`/var/lib/*`), SSH keys, NetworkManager, machine-id
- `/persist` — user home dirs: desktop folders, config repos

**Adding a new Btrfs subvolume under `/`:** Add the mount-point dir to the validation list in `modules/features/impermanence.nix`, then update `@blank`:
```sh
sudo mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
sudo btrfs subvolume snapshot -r /mnt/@ /mnt/@blank-tmp
sudo btrfs subvolume delete /mnt/@blank
sudo mv /mnt/@blank-tmp /mnt/@blank
sudo umount /mnt
```

**Initrd constraint:** The rollback script runs in the systemd initrd. The module guarantees exactly `btrfs`, `mount`, `umount`, `chmod`, `mkdir` via `boot.initrd.systemd.storePaths` (`modules/features/impermanence.nix`) — write the script against those. Note that on 26.05 the systemd initrd *also* ships coreutils/systemd userspace by default (`initrdBin`), so more is available in practice, but don't rely on it; stick to the guaranteed set (plus bash builtins for control flow — no `grep`, `awk`, `sed`, `find`, `ls`).

---

## Known Gotchas

### Plymouth + AMD GPU (yoga)

`amdgpu` loaded in initrd unregisters `simpledrm` before Plymouth can attach. This causes the LUKS prompt to fall back to text mode with an 8s delay.

**Root cause:** `amdgpu` probes the GPU → calls `drm_aperture_remove_conflicting_framebuffers()` → simpledrm device torn down → Plymouth's `use-simpledrm` predicate finds no device → 8s timeout → text-mode fallback.

**Why cold boot works, reboot fails:** Cold boot loads amdgpu firmware from disk (~3-5s), simpledrm survives long enough. Reboot loads from CPU/RAM caches (<1s), simpledrm is gone before Plymouth starts.

**Current state:** amdgpu is kept out of the initrd by `hosts/yoga/default.nix`: a modprobe.d blacklist (`boot.initrd.systemd.contents."/etc/modprobe.d/no-amdgpu.conf"`) blocks udev modalias auto-load, and `boot.initrd.kernelModules = lib.mkForce [...]` pins the initrd allowlist (btrfs, dm_mod — kvm/kvm-amd moved to stage 2, 2026-10-24). Plymouth attaches to simpledrm deterministically. amdgpu loads normally after switch-root.

**Verification:**
```sh
# amdgpu must NOT be in initrd
sudo lsinitrd /nix/store/*-initrd-linux-*/initrd 2>/dev/null | grep amdgpu
# Should be empty

# Plymouth should attach to simpledrm
journalctl -b -o cat | grep -E "simple-framebuffer.*Registered|plymouth.*Attached"
# Should show simpledrm registering before Plymouth attaches
```

### linux-firmware yellow_carp DMCUB regression (yoga) — RESOLVED 2026-09-19

linux-firmware 20260910 (nixpkgs-26.05, Sept 2026) shipped a regressed `yellow_carp_dmcub.bin` (RH bugzilla 2532947): on Rembrandt iGPUs (yoga) the display froze/black-screened on blank/lock/suspend. Interim mitigation was a pin to the 20260810 snapshot (flake input `nixpkgs-firmware-pin` + overlay). Resolved by linux-firmware **20260916** (AMD revert); the pin was removed and the nixpkgs lock bumped in the same change. If a future firmware snapshot reintroduces DMCUB errors (`failed to load ucode DMCUB(0x3F)`), check [bugzilla 2532947](https://bugzilla.redhat.com/show_bug.cgi?id=2532947) and re-pin the same way.

### Retired desktop stack — Hyprland / Lucid / DMS / quickshell (2026-11-14)

The whole quickshell-based desktop stack (Hyprland + Lucid shell + DankGreeter, plus the DMS/dux-shell evaluation material) was **removed from main on 2026-11-14** when niri + Noctalia became the primary `yoga` attr. The complete stack, its inputs, the 19-patch lucid layer, the German dictionary, LUCID_RUNBOOK.md and the wrapped-quickshell overlay live on the **`archive/hyprland-lucid` branch** (and the `dux-shell` branch for DMS); full per-file documentation of that era is in that branch's REPO_OVERVIEW and the git history of `docs/knowledge/nixos-config/`.

Still-load-bearing mechanics that era produced (they govern the noctalia greeter/lock units the same way):

- **home-manager turns a unit's `Install.WantedBy=<target>` into a generated target fragment with `After=`+`Wants=` on that unit** — binding session services through WantedBy adds real ordering; plain `.wants` symlinks do not.
- **Lock-at-boot trap (2026-09-25, found on lucid):** a oneshot `WantedBy=graphical-session.target` with **no ordering of its own** gets an implicit `After=` FROM the target, so the target waits for it. A lock oneshot that waits on a shell unit which is itself `After=graphical-session.target` deadlocks the boot ~10 s. Rule: any unit wanted by a target that must wait for another unit wanted by the same target orders itself `After=` the target, never after the sibling — that is why `noctalia-lock-at-boot` (and the retired `lucid`/`dms` equivalents) carries `After=graphical-session.target`.
- `nixos-rebuild switch` does NOT pull newly-wanted units into an already-running target — after changing target bindings mid-session, start the unit manually or reboot.

### Jellyfin on nix-media — versioning & operations notes

The container runs `:latest` and follows the weekly `docker-image-refresh` timer (Sun 03:00, `Persistent=true` — missed fires catch up at the next boot). Auto-updates are an accepted trade-off (2026-09-19). How 12.0 arrived: the host was powered off 2026-08-30 → 09-11, during which `:latest` moved to 12.0; at boot the unit found no local image (Monday `docker-prune --all` had removed it), pulled `:latest` = 12.0, and the schema migrated on first boot — the documented manual upgrade process was never followed and no pre-upgrade backup exists. **10.x is NOT a rollback path** (schema mismatch: "no such column" errors, verified 2026-09-19).

- Server serves at `/` (BaseUrl env is not applied); Caddy's `strip_prefix /jellyfin` is the working combo. The health-cmd probes `/health`.
- intro-skipper `DOCKER_MODS` removed 2026-09-19: ghcr.io returns 403 DENIED (project dropped the docker-mod); the plugin persists in `/config/data/plugins` and updates via its version-aware manifest repo (`https://intro-skipper.org/manifest.json`).
- Backup gap: only a single automatic zip from 2026-02-02 plus ad-hoc tars — enable Jellyfin's scheduled backup task before the next X-major release lands via the timer.
- Since 2026-10-31 `docker-image-refresh` digest-compares each image before restarting: unchanged digests are skipped (no more unconditional Sunday 03:00 bounce), and a jellyfin restart is skipped while ffmpeg is mid-transcode — the weekly timer retries next Sunday. Docker daemon gains `live-restore`, and both media containers gate on `/mnt/storage` via `RequiresMountsFor` (nofail disks otherwise let dockerd create empty bind-source dirs on the root FS). Container stdout logging stays on NixOS's journald driver (capped by the host's journald config) — json-file `log-opts` would crash dockerd (journald driver rejects them; VM-proven 2026-10-31).

### NixOS 26.05 Breaking Changes

| Change | File | Fix |
|--------|------|-----|
| `services.resolved.extraConfig` removed | `modules/core/networking.nix` | Migrate to `services.resolved.settings` attrset |
| `gdm.wayland` removed (Wayland mandatory) | `modules/features/desktop-gnome.nix` | Delete `wayland = true` line |
| `programs.adb` removed | `modules/core/users.nix` | Use `pkgs.android-tools` in systemPackages |
| Grafana `secret_key` required | `hosts/nix-media/monitoring.nix` | Set `secret_key = "SW2YcwTIb9zpOOhoPsMm"` |
| `fastfetchMinimal` renamed | `hosts/nix-media/default.nix`, `home/terminal.nix` | Change to `fastfetch.minimal` |
| `nixfmt-rfc-style` renamed | `flake.nix` | Change to `nixfmt` |
| WinApps removed | `flake.nix`, `home/`, `hosts/yoga/` | Replaced by virt-manager/libvirt |
| opencode `libstdc++.so.6` missing | `home/opencode.nix` | Wrap binary with `LD_LIBRARY_PATH` pointing to `stdenv.cc.cc.lib` (moved from `home/terminal.nix` → `hosts/yoga/opencode.nix` → shared `home/opencode.nix` when opencode was extracted to a shared module) |
| Docker 28 marked insecure | `hosts/nix-media/docker.nix` | Pin `package = pkgs.docker_29` |
| `environment.extraTerminfo` removed | `hosts/nix-media/default.nix` | Use `environment.enableAllTerminfo = true` (pulls kitty/ghostty/tmux/… terminfo outputs) |
| `hardware.cpu.*.updateMicrocode` defaults to plain `false` | `modules/hardware/default.nix` | Upstream decoupled it from `enableRedistributableFirmware` — the isPhysical branch now sets both vendors `mkDefault true` (verified against the pinned nixpkgs 2026-10-17; wrong-vendor ucode blob is inert) |

**First switch after upgrade requires reboot** — dbus-broker replaces dbus-daemon, needs full restart.

### Disko adoption without reinstall (latitude)

`hosts/latitude/disks.nix` generates mounts by GPT **partlabel** (`/dev/disk/by-partlabel/ESP`, `…/cryptroot`), but the pre-disko install was partitioned by the installer with no matching labels. Rebuilding the live system on the new config **before** fixing the labels produces an unbootable initrd (LUKS device never appears). Either reinstall via `scripts/install.sh` (disko sets the labels at format time), or relabel the existing partitions first — non-destructive, metadata only:

```sh
lsblk -o NAME,PARTLABEL,FSTYPE        # verify: partition 1 = vfat, 2 = LUKS
sudo sgdisk --change-name=1:ESP --change-name=2:cryptroot /dev/sda
```

The LUKS mapper name (`nixos`) and filesystems are untouched — only discovery paths change (by-uuid → by-partlabel) and `allowDiscards` is newly set on the LUKS entry.

### Suspend-then-hibernate (yoga)

A battery suspend opens a 2h s2idle window, then hibernates — for lid-close suspends at the first deadline, for idle suspends (lid open) at the second consecutive deadline (added 2026-10-19). Implemented by the `yoga-s2h` system-sleep hook (`hosts/yoga/yoga-s2h.nix`, installed at `/etc/systemd/system-sleep/yoga-s2h`) — **not** by `HandleLidSwitch=suspend-then-hibernate`.

**Why not systemd's built-in s2h (systemd 260):** it never hibernated on this machine — silently. Validated against `src/sleep/sleep.c` (v260) plus the journal (2026-09-03..05):

- s2h suspends with a `CLOCK_BOOTTIME_ALARM` timerfd; the kernel derives the RTC wakealarm from it, truncated to whole RTC seconds, so the machine wakes up to ~1s **before** the µsec-precision timerfd deadline.
- After the wake, `custom_timer_suspend()` polls the timerfd with zero timeout: no `POLLIN` yet → `woken_by_timer=false` → `return 0` ("manual wakeup") with no journal message. Every `woken_by_timer=true` path leads to hibernation; the kernel journal shows zero `PM: hibernation: hibernation entry` lines across every deadline wake over three days.
- The lid is still closed, so logind re-applies `HandleLidSwitch` when its 30s resume holdoff (`HoldoffTimeoutSec`) expires → fresh s2h instance → new 2h (or 1h, when the discharge-rate estimate falls back to `SuspendEstimationSec`) window. Observed: nightly 2h loops, zero hibernations, ~30s awake per cycle — the source of the extra battery drain.
- The battery-estimation path is separately broken here: capacity reports in 1% steps, so long-interval discharge estimates round to 0 and are rejected (`BAT0: Failed to update battery discharge rate, ignoring: Numerical result out of range`), and the persisted rate `/var/lib/systemd/sleep/battery_discharge_percentage_rate_per_hour` held garbage. Matches upstream reports (systemd issues #33843, #35743); if fixed upstream, the built-in can be revisited.

**The hook instead:** on every battery suspend (lid or idle — both plain `suspend`) it stores a deadline in `/run/yoga-s2h-deadline` and arms every `/sys/class/rtc/rtc*/wakealarm` (write `0` first, then the epoch value). On resume: more than 60s before the deadline → manual wake (lid open/AC: clear everything) or spurious wake (lid still closed on battery: clear only the RTC alarm, **keep the deadline** so hibernation time doesn't slide out 2h per wake; logind's holdoff re-suspends); within the window + lid still closed + still on battery → schedule the hibernate 3s out via a transient unit (`systemd-run --on-active=3s systemctl hibernate` — see the logind note below); within the window + lid open + still on battery (the idle-suspend case) → the first elapsed window re-suspends 15s out via the `recheck` transient unit — the machine is awake ~15s per cycle instead of the old "stay awake until hypridle's 2h idle timer re-suspends" — and opens a fresh 2h window; the **second consecutive** elapsed window hibernates through the same deferred unit. Manual wake, AC, a completed cycle or a reboot clear the consecutive-window counter (`/run/yoga-s2h-openlid`), so a briefly-away machine stays in cheap s2idle and only an idle suspend left unattended for >4h pays for a full hibernate (2026-10-19; before that, an open-lid deadline stayed awake indefinitely and idle suspends never hibernated). The 60s tolerance makes the timer-vs-manual classification immune to the same second-granularity race that breaks systemd's implementation (the hook's deadline is whole seconds, same as the RTC alarm). Known limits: low battery does not trigger early hibernation (this firmware exposes no ACPI battery alarm — the reason systemd ran its estimation loop at all); if AC is plugged during suspend without waking the machine, it stays awake at the deadline (logged) rather than hibernating; the 15s recheck re-suspends even if the user walks up in exactly that gap (one ordinary suspend a keypress wakes).

**logind refuses sleep/reboot requests made from inside sleep hooks (systemd 260):** `systemctl hibernate` called by a `post suspend` hook is always rejected — logind holds `delayed_action` until the suspend *job* completes (`match_job_removed()`), and that happens only after the post hooks exit. First observed 2026-09-06 ("Call to Hibernate failed: Action suspend-then-hibernate already in progress"), and it applies equally to plain suspends and to reboot requests. Hence the 3s deferral through a transient unit: by then the job is gone, logind accepts the request, and — crucially — it re-arms `delayed_action` plus the 30s lid holdoff for the whole hibernate write, which is the only thing preventing logind from re-triggering the still-closed lid into a concurrent suspend mid-image-write (starting `systemd-hibernate.service` directly would dodge the refusal but lose exactly that protection; logind does not track directly-started sleep units). A failed/aborted hibernate self-heals via the same deferral: `post:hibernate` records a decision and schedules a 15s `recheck` self-invocation that re-evaluates lid/AC and executes it (see the abort-handling notes below); the open-lid window-1 re-suspend rides the same `recheck` unit (decision `openlid-resuspend`, checked before the abort guard since lid open is the expected state there). **Fixed 2026-09-09:** the deferred unit runs the hook with `$1=recheck` and no `SYSTEMD_SLEEP_ACTION`, so the case word is `recheck:` — the old bare `recheck)` pattern never matched and the abort response silently never fired; the pattern is now `recheck:*)`.

**sleep.conf key names (systemd 260):** the mem_sleep selector is `MemorySleepMode=`, *not* `SuspendMode=` — that key does not exist and unknown keys are silently ignored. Symptom (2026-09-07 journal): every suspend logged `PM: suspend entry (deep)` → instant exit → `PM: suspend entry (s2idle)` — the firmware rejecting S3, then systemd's own <5s-retry falling back. With `MemorySleepMode=s2idle` systemd-sleep writes `s2idle` to `/sys/power/mem_sleep` directly. (`HibernateMode=` *is* valid; `/sys/power/disk` showed `[shutdown]` selected after the 2026-09-07 04:00 hibernate.) Verify after a rebuild+reboot: `systemd-analyze cat-config systemd/sleep.conf` and a single `PM: suspend entry (s2idle)` line per suspend in the journal.

**First full-cycle telemetry (night 2026-09-07, upower history `L21D4PE0`):** lid/idle suspend 02:00:22, RTC wake at 04:00:22 *to the second*, zram swapoff + image write (534018-page snapshot ≈ 2.0G, 7.6s prealloc, ~2min reclaim), powered off ~11h, resumed 14:58 with `amdgpu SMU is resumed successfully`. **Total battery cost: 35%→34% (≈1%), implying ~0.25–0.5%/h s2idle drain — S0ix is healthy on this machine (the `rtc_cmos.use_acpi_alarm=1` cmdline is load-bearing for that), and the 2h `DELAY` is cheap.** Perceived "10% lost overnight" was actually the hour *before* the suspend: an awake session at 9–25W (a rebuild at 00:48, heavy load to ~01:45, ~9W idle desktop until GNOME's idle-suspend fired at 02:00) burned ~22% in 70min — the suspend/hibernate path itself is not the drain.

**Operational: `nixos-rebuild test` does not restart logind.** After a `test` switch, the live logind keeps its old in-memory lid policy (observed via busctl: `HandleLidSwitch` still `suspend-then-hibernate` while /etc already said `suspend`). Every lid close then runs systemd's built-in s2h, whose in-progress state blocks the hook's hibernate on top of its own timer bugs. Fix: reboot (or `systemctl restart systemd-logind`) after changing lid/sleep policy via `test`.

**Hibernation image vs zram:** the image must fit in free RAM after the kernel's own reclaim, but zram keeps swapped pages resident — at ~9.5G in use the image (8.5G) exceeded freeable RAM (7.8G) → `-ENOMEM` (2026-09-03). The hook's `pre hibernate` swaps zram out to the disk swapfile (frees the compressed pool, removes those pages from the image). **Re-enabling zram needs more than `swapon`:** `swapoff` auto-resets the zram device to disksize 0, so `swapon /dev/zram0` fails with "could not read swap header" (journal 2026-09-06). `post hibernate` instead restarts `systemd-zram-setup@zram0.service`, whose ExecStop (`--reset-device`) + ExecStart (`--setup-device`) recreate size/algorithm/priority from the NixOS-generated `zram-generator.conf` — covers real resumes, failed and aborted attempts alike. **Resume race (2026-10-18 19:59:11):** ~22 ms after hibernation exit something re-initialized zram0 (correct size + lz4) before the hook's restart ran; the generator's first write failed with "Can't change algorithm for initialized device" (EBUSY) and never reached mkswap/swapon — zram swap stayed off until the next reboot, and with it the pre-hibernate zram swap-out would have been silently skipped (the 2026-09-03 ENOMEM setup). The hook now settles 2s, skips when zram is already swapped on, and on a failed restart resets the device (`zramctl --reset`, fallback `echo 1 > /sys/block/zram0/reset` — the kernel rejects `disksize=0` with EINVAL) before `systemctl start`; every path then verifies the actual swapon via `/proc/swaps` (poking `dev-zram0.swap` once if the generator's dependency chain stalls) instead of trusting the setup unit's exit code, and `pre:hibernate` logs loudly when zram isn't swapped on at image time.

**amdgpu/TTM hibernate instability (2026-09-06 incident; ROOT-CAUSED 2026-10-16, see the re-arm bullet below):** the first-ever hibernate attempt aborted *in place* — snapshot allocated, amdgpu MODE2-reset mid-device-suspend, `syscore_resume` WARNING on the unwind, no image ever written. ~20 min later the kernel oopsed in `ttm_lru_bulk_move_tail` (NULL deref via `amdgpu_cs_ioctl`), and a subsequent `DRM_GEM_CLOSE` spun on the corrupted TTM spinlock until both CPUs hard-locked (power-cycle at 01:26). This is the TTM bulk_move use-after-free (CVE-2026-98166, introduced by commit `b2ed01e7ad3d`): at the time it was believed an unfixable amdgpu bug class (tracked as drm/amd #5470, #5703, #5517, #5715) and "unfixed through mainline 7.3-rc1" — but the actual fix (return-value check in `ttm_bo_swapout_cb`) landed 2026-09-09 and is in the running kernel. Mitigations applied (kept as hygiene):

- `/sys/power/image_size` capped at 4G via tmpfiles. This bounds the hibernation snapshot and thus how deep the pre-snapshot reclaim goes (the screen-dark wait): 2G gave 3.6× free-page margin (needed 860K pages, 3.1M available, 2026-09-07) but cost a 17-minute reclaim on a heavy session; 4G halves that while keeping >1.5× margin. The old ~5.9G kernel default only caused the 2026-09-03/06 ENOMEM aborts because zram kept swapped pages resident in RAM — now swapped out by the hook first, which was the real fix. Verify margins per attempt via the journal's "Normal pages needed: X, available pages: Y" lines; if Y/X drops toward ~1.2, lower the cap again. Closing memory-heavy apps before a manual hibernate still shortens the reclaim.
- `HibernateMode=shutdown` — power off via plain shutdown after writing the image, skipping the firmware's ACPI-S4 platform path (this firmware's ACPI layer is the same one with the broken S3 and the RTC wakealarm truncation bug). Verified applied on the successful 2026-09-07 cycle.
- **RESOLVED (2026-10-18): hibernation WORKS on 7.2.9 — the "every attempt aborts" narrative was an artifact of a broken abort detector.** The kernel INJECTS the hibernation off-time into CLOCK_BOOTTIME at resume, so after a real cycle `uptime == wall-since-boot` — which the old detector (and our whole September analysis method) interpreted as "never powered off ⇒ in-place abort". Two verified-real cycles on 7.2.9-zen1: 2026-10-17 13:49 (off ≈50s; tailscaled "slept 1m3s") and 2026-10-18 00:24 (off ≈10min; tailscaled "slept 10m59s", monotonic advanced 25.5s vs wall 659s) — the second was misclassified by the hook as a deep abort ("reboot pending"; survived because the lid was open). The `usb 3-3` WARN, `SMU is resuming` replay and same-second journal stamps are all NORMAL for a completed cycle (replayed kmsg records carry hibernate-time monotonic stamps; journald reads them at resume). Detector rewritten: real resume ⇔ BOOTTIME−MONOTONIC divergence grows by the off-duration (>10s); in-place abort ⇔ divergence unchanged + uptime growth >30s; monotonic via journalctl, detection skipped if unavailable. Flag re-armed (`HIBERNATE_ENABLED=1`). **Historical reclassification:** attempts on 7.2.9 were successes; the 2026-09-06 corruption and 2026-09-03 ENOMEM were real (pre-fix kernel); September 7.1.10/7.2.3 "aborts" can no longer be classified (journals rotated out past Sep 16) — the deciding question is physical: did the machine power off (fans/LED off, power button needed) in those rounds? September rounds read as "returned to desktop by itself", which genuine aborts would also look like — unresolved. The wake-pending hypothesis below was never tested and is moot. The Sep-6-class post-abort TTM corruption risk is fixed by CVE-2026-98166 anyway (14+ clean unwinds/resumes since, zero oopses).

- **Superseded hypothesis (2026-10-17, never tested — see RESOLVED above): wake-pending abort.** Independent review (Claude) of the handoff brief pointed at `create_image()`'s post-freeze `pm_wakeup_pending()` check: a wakeup event during the freeze window would skip image creation and unwind through *restore* callbacks **returning success** — no error lines, systemd never fails ("Wakeup pending" is debug-level since 2018). Its valuable contributions: proving "no device ever failed" (zero error lines across all journals) and — in the follow-up round — identifying that our "abort" readings were compatible with *successful* cycles, which led to the RESOLVED finding. The wake-source survey remains useful reference: `/proc/acpi/wakeup` shows five S4-enabled xHCI controllers (XHC0–XHC4) + GPP7; chattiest wake source is the Elan touchpad (`i2c-ELAN06FA:00`).

- **Superseded (2026-10-18) — re-parked 2026-10-17 under what turned out to be a broken abort detector; see RESOLVED above (attempt #14 was a success).** The CVE-2026-98166 fix was necessary but not sufficient for the *pre-fix* abort story. Attempt #14 (2026-10-17 13:49, supervised, lid open) ran on 7.2.9-zen1 — the first fix-bearing kernel ever attempted (all 13 prior failures were on pre-fix kernels: zen 7.1.10 ×10+, vanilla 7.2.3 ×3, see below) — and aborted **identically**: freeze-pass failure, `usb 3-3: WARN: invalid context state`, deep amdgpu unwind, `hibernation exit`, no image. Verdict: the CVE fix eliminated the *post-abort* TTM-corruption risk (Sep-6 delayed-oops class — 14 clean unwinds since, zero oopses), but the *abort* itself is a separate, quasi-deterministic failure in the amdgpu/ACPI S4 entry path on this hardware (1 fluke success in 15 attempts, Sep-7 04:00). Every USB-level and sequencing manipulation was already tried and is documented below — none changed the outcome. **While parked: suspend-only** (s2idle ≈0.25–0.5%/h), no RTC timer. **Do not re-arm while aborts persist** — unattended lid-close → 2h → hibernate → deep abort → auto-reboot (lid closed) → loop on fragile GPU state. Remaining cheap/untried levers, in order: drop `amdgpu.ppfeaturemask=0xffffffff` from the cmdline (PowerPlay features touch the suspend path; constant across all failures *and* the success, so a probe, not a known cause — check nothing relies on it first); kernel 7.3.y once it lands in nixpkgs (amdgpu S4/TLB work since 7.2); upstream report with the journal evidence. Standing rules unchanged: after any in-place abort, reboot promptly; abort detector requires uptime growth ≥30s AND wall-vs-uptime skew <60s; s2idle telemetry ≈0.25–0.5%/h (~3–4%/night).
- **Automated abort response (verified live 2026-09-07 22:02):** `post:hibernate` detects an in-place abort via `/proc/uptime` growth during the attempt (>45s ⇒ the whole reclaim/snapshot/unwind ran in this kernel; a real resume restores the frozen clock and only seconds pass). This is necessary because the kernel can abort *and still return success* from the `/sys/power/state` write — at 2026-09-06 23:38 `systemd-hibernate.service` never entered failed state and logged no error, so `systemctl is-failed` (kept as a secondary trigger for systemd-level failures like the 2026-09-03 ENOMEM) is blind to kernel aborts. On the 22:02 deep abort the hook correctly logged "hibernate aborted AFTER amdgpu suspend (TTM corruption risk)" within a second. Response is depth-aware: if the kernel log since the attempt started contains `SMU is resuming`, amdgpu went down and was unwound — the exact Sep-6 corruption precondition — so unattended (lid closed, battery) the hook reboots after 15s and `wall`s a warning if the user is present; a shallow abort (no amdgpu involvement, like 23:38) just re-suspends and retries in 2h. Caveat learned at 22:02: **`wall` does not reach a GNOME session** — an aborted manual hibernate just drops you back on the desktop looking "successful". Rule of thumb: if a manual hibernate returns you to the desktop instead of powering the machine off, it aborted — reboot promptly.
- Operational rule (still true for manual tests): **after any hibernate attempt that aborts in place (journal shows `hibernation exit` in the same boot, no power-off), reboot promptly** — the automated path covers unattended cycles, but a manually-triggered abort with the lid open only warns.

**Impermanence rollback vs hibernate resume:** `rollback-root` (initrd, `modules/features/impermanence.nix`) wipes and recreates `@` on every boot and originally had no ordering against `systemd-hibernate-resume.service` — on a resume boot the two raced (journal shows "Deleting subvolume" interleaved with the resume attempt), which would put a resumed session's writes into a deleted subvolume. `rollback-root` is now ordered `After=systemd-hibernate-resume.service`: on a real resume the kernel jumps into the restored image during that unit and the initrd (hence the wipe) never finishes; on normal boots the unit fails fast ("Image not found") and the wipe proceeds — ordering against a failed unit doesn't block.

**NixOS hook PATH pitfall:** system-sleep hooks run with a minimal PATH — `grep` was missing (`grep: command not found` in the journal) while `swapon` happened to resolve. The hook sets `PATH` explicitly via `lib.makeBinPath`.

**Agent pitfall — the ZCode shell does not see the host's `/etc`:** agent tool shells run sandboxed inside the ZCode fhsenv, which bind-mounts its own `/etc/systemd` (and friends) over the host paths (`findmnt /etc/systemd` shows a `zcode-…-fhsenv-rootfs` source; `sudo` is blocked by `no_new_privileges`). Checking live config files like `/etc/systemd/sleep.conf` from an agent shell therefore gives *wrong answers*. Host truth: journalctl output, `/run/current-system` / `/run/booted-system` store paths, and `/sys` (which passes through) — verify applied sleep config via the journal (`PM: suspend entry (s2idle)`, single line per suspend) rather than `systemd-analyze cat-config` from the sandbox.

**Prereq:** `resumeDevice` + `resume_offset=7697093` (via `btrfs inspect-internal map-swapfile -r /var/lib/swap/swapfile` — re-derive if the swapfile is ever recreated; stale offset = boots fresh instead of resuming, no corruption).

### Switch restart tears down live zram swap (yoga/latitude, fixed 2026-10-19)

A nixpkgs bump that changes `zram-generator` breaks zram swap at the next `switch`: nixpkgs already pins `restartIfChanged = false` on the `systemd-zram-setup@` template (`zram-generator.nix`, citing systemd/zram-generator#226 — after swapoff udev still holds the device, the reset EBUSYs, and the device stays initialized), so switch-to-configuration **skips** the service — but NOT the swap unit: daemon-reload regenerates `dev-zram0.swap` (the generated file embeds the generator's store path) and s-t-c restarts changed swap units unconditionally (a raw swap unit cannot carry the `X-RestartIfChanged` skip flag; `systemd.units.<name>` has no `restartIfChanged`/`dropins` options). The swap restart's `BindsTo` (bindings.conf) drags the pinned service down with it, and zram-generator cannot re-setup an already-initialized device — kernel: `Can't change algorithm for initialized device` (EBUSY on `comp_algorithm`). Every subsequent start fails the same way, so zram stays off (disk swapfile still active) until a manual reset or reboot; the s2h hook's zram re-create path hits the same stuck state.

**Fix** (`modules/features/zram.nix`, `hosts/yoga/yoga-s2h.nix`): a template-level `ExecStartPre` on `systemd-zram-setup@` (parameterized with `%i`) ensures a **fresh device** before every setup: if the device is initialized with no swap on it, reset it — and then, kernel 7.2.9 specifics — re-create it via `/sys/class/zram-control/hot_add`, because on this kernel a reset **removes the device entirely** (journal 2026-10-19 00:46: `zramctl --reset` → `zram: Removed device: zram0` → setup dies with ENOENT on `comp_algorithm`; the first staged heal, and the s2h hook's older manual reset, did exactly that). On kernels where a reset only clears the device, the hot_add step no-ops (device still present, disksize 0). The s2h hook's resume branch now just restarts the setup unit and lets the ExecStartPre own the whole dance. The template-level def inherits nixpkgs's `util-linux` PATH (`zramctl`). Recovery for a box with the device already missing: `new=$(sudo cat /sys/class/zram-control/hot_add)` (expect `0` → `zram0`), then `sudo systemctl start systemd-zram-setup@zram0.service dev-zram0.swap`.

**Adjacent trap — instance-level defs shadow upstream templates:** defining `systemd.services."systemd-zram-setup@zram0"` (instance-level) makes NixOS emit a standalone `systemd-zram-setup@zram0.service` containing only the overrides — no `ExecStart` — which **shadows** the upstream template for that instance. systemd then refuses the unit outright (`Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing.`) and every `dev-zram0.swap` start dies with "bad unit file setting" (generation 187, 2026-10-19). Rule: extend upstream template units at the **template** level (`"systemd-zram-setup@"`), never the instance level; `%i` carries the instance into Exec scripts.

### Power tuning status (yoga) — audited 2026-09-19

Verified live on battery: `amd-pstate-epp` driver, governor `powersave`, EPP `balance_power` on all 16 CPUs — exactly the TLP intent (`hosts/yoga/default.nix`), nothing fights it. system76-scheduler runs alongside but only touches CFS knobs (latencies/nice), not EPP/governors, and is not on TLP's conflict list. Remaining stack: ryzenadj caps (AC 50/60/50W, battery 15/25/15W via `modules/hardware/ryzen-tdp.nix`), zen kernel + `nowatchdog`, zram lz4 (keeps the NVMe asleep), btrfs `noatime zstd:1 discard=async`, 15s dirty writeback, TLP built-ins (sound power-save, Wi-Fi powersave, runtime PM). TLP's own defaults already set `WIFI_PWR_ON_BAT=on` and `SOUND_POWER_SAVE_ON_BAT=1`; no need to spell those out per host.

**Panel refresh switch** (`home/battery-refresh.nix`, the one real lever added by the audit — ~0.5–1 W at light load): 120 → 60 Hz on battery. The panel's EDID carries a native `3072x1920@60` timing (verified by parsing `/sys/class/drm/card*-eDP-1/edid`; DRM exposes both 3072x1920 modes). The daemon compares the panel's ACTUAL refresh rate — probed every poll (niri: the `current_mode` index into `niri msg -j outputs`, `refresh_rate` in millihertz; GNOME: the ` CURRENT`-marked mode in `gnome-monitor-config list`) — against the desired one for the power state and re-applies on any mismatch, so AC transitions, lid reopen (the lid switch restores the configured 120 Hz mode) and compositor-side resets all self-heal within one poll. (Until 2026-10-24 it acted on remembered-state changes only, and a hibernate resume — which re-applies the configured 120 Hz mode on thaw — silently left the panel at 120 Hz on battery.) It never acts while the lid is closed (the panel is disabled — applying to a disabled panel is at best a no-op); the GNOME variant additionally refuses to run while any DP/HDMI output is connected because `gnome-monitor-config set -L` replaces the *whole* monitor configuration. Every session runs it as `systemd.user.services.battery-refresh` bound to `graphical-session.target` (since 2026-09-22). A failed probe or apply retries on the next poll instead of being swallowed. Caveat: gmc is `0-unstable-2023` against mutter's versioned DisplayConfig D-Bus API — if GNOME ever breaks it, the symptom is simply no switching (daemon logs an apply error), nothing else. niri attr (backend added 2026-11-07): the apply strings follow niri's exact-match grammar — resolution-only `3072x1920` (= highest rate, AC) and `3072x1920@60.000` (battery; plain `@60` would never match, three decimals required). NIRI_SOCKET reaches the user manager because `niri-session` imports it. Gotcha learned the hard way during the trial: niri picks the panel's **preferred** mode when the output `mode` is omitted, and this EDID pins preferred at 60 Hz — "omitted = highest" is NOT a niri behavior, so `home/niri.nix` carries the explicit resolution-only mode. Revert: `desktop.battery-refresh.enable = false`.

**Idle policy** — **historical DMS spec (2026-09-22):** DPMS off / lock / suspend at 3/5/15 min on battery and 10/15/60 on AC, seeded via DMS. Since the Lucid migration the idle timers live in Lucid's own Idle settings page (`~/.config/quickshell/lucidprefs/prefs.json`, user-configured; see the Lucid deployment gotcha) — the DMS seed is gone with the DMS shell. Lid policy stays `profiles/laptop.nix` (suspend on battery, clamshell awake on AC — the fixed lid bind powers the internal panel off on AC). Charge cap (conservation mode) explicitly declined 2026-09-22: stays off.

**Browser video decode** (software decode costs 3–6 W on the 680M): Firefox ≥136 enables VA-API by default (156 in the lock — nothing to configure). Brave 1.95.101 is ≥1.85 (Wayland hardware decode default-on since Chromium issue 40225939); `hosts/yoga/home.nix` additionally pins `--enable-features=VaapiVideoDecodeLinuxGL` as insurance. Runtime verification: `brave://gpu` must show "Video Decode: Hardware accelerated"; `chrome://media-internals` during playback must list `VaapiVideoDecoder`, not `VpxVideoDecoder`.

Deliberately **not** done (documented so it isn't re-litigated):

- `amdgpu.dcdebugmask=0x10` (disables PSR): popular 680M glitch "fix" that *costs* idle power — PSR is a power-saving feature and stays on.
- powertop `--auto-tune`, auto-cpufreq, system76-power: all conflict with TLP per linrunner.de/tlp/faq/conflicts.html.
- `CPU_BOOST_ON_BAT=0`, non-zen kernel: trades exactly the responsiveness this balance is built around.
- iGPU `power_dpm_force_performance_level=low` on battery (reported effective on the comparable Rembrandt ThinkPad Z13): small win, glitch risk; candidate implementation = extend `set-ryzen-tdp` (`modules/hardware/ryzen-tdp.nix`) which already has the AC/battery trigger plumbing.
- `PLATFORM_PROFILE_ON_BAT=low-power`: slightly more clock clamping under load than the current `balanced`.
- Battery charge cap: this EC has no `charge_control_end_threshold`, but Lenovo conservation mode exists at `/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/VPC2004:00/conservation_mode` (reads `0` = off, 2026-09-19). It's a longevity feature (caps charge), not a runtime one, and changes charging behavior — offered 2026-09-22, declined by the user; only to be enabled on explicit request.

Expectations: 70 Wh battery with the 25 W battery cap ≈ 2 h under genuinely heavy load regardless of tuning; software tuning pays off in light load and browsing, where panel + iGPU dominate. s2idle drain 0.25–0.5%/h is healthy (see the suspend-then-hibernate section above).

### yoga WiFi: iwd band-flapping between mesh BSSIDs (mitigated 2026-10-06)

Symptom: constant 5GHz↔2.4GHz switching on the home mesh SSID (`FRITZ!Box 7590`, one SSID across several AVM/MikroTik radios) — 617 `roam-info` events in one boot (previous boots: 1–3), ping-ponging between exactly two BSSIDs. NetworkManager is exonerated (zero roam lines in its journal): with the iwd backend all roam decisions are iwd's (`roam-scan` → `ft-roaming`, 802.11r FT). Mechanism: both bands hover at iwd's default roam thresholds (-70 dBm 2.4GHz / -76 dBm 5GHz), so every roam-scan finds the other band marginally better. Fix (`hosts/yoga/default.nix`, `networking.wireless.iwd.settings`): `RoamThreshold=-74`, `RoamThreshold5G=-80` (lazier roaming; `CriticalRoam*` stays at defaults -80/-82 as the must-roam floor), `Rank.BandModifier5GHz=2.0` (5GHz bias when both bands are viable). Option spellings per deployed iwd 3.12 `iwd.config(5)`: `RoamThreshold5G` and `BandModifier5GHz` — not "5Ghz". Dead ends already ruled out: NM per-connection `band=`/`wifi.powersave` are inert under the iwd backend (e5ca1e1); kernel-level wifi powersave was already off. Revert = delete the three new keys and re-switch; note the `/etc/iwd/main.conf` change needs `systemctl restart iwd` (or reboot) to apply — a switch alone may not restart the daemon.

### yoga WiFi: post-resume EC rfkill glitch can wedge iwd (2026-10-24)

Symptom: minutes after an s2idle resume, wifi drops (`deauthenticating … by local choice`, `CMD_TRIGGER_SCAN: Network is down`) and then EVERY connect — autoconnect, manual click, freshly typed PSK — fails instantly with iwd `connect-failed, status: 1` while the kernel logs ZERO auth frames (the requests die in userspace, so it is never a wrong password). iwd does not recover on its own; the lucid panel showed "Kein Passwort für dieses Netzwerk gespeichert.", which for a SAVED network is a red herring — NM's NoSecrets failure mapping, the credentials were intact throughout. Trigger: the `ideapad_wlan` platform rfkill (Lenovo EC) toggles after resume (`rfkill id 0 not found in a RFKILL_OP_CHANGE event` opens the incident in iwd's journal); fired twice on 2026-10-24 — 12:06 self-healed in 2 s, 22:49 wedged ~3 min. Heal: wifi off/on (rfkill cycle → iwlwifi firmware re-init → next connect succeeds in seconds). `129-wifi-connect-resilience` makes the panel honest (generic failure text + one silent retry) but a hard wedge still needs the manual toggle; no kernel-side fix — `ideapad_laptop` is load-bearing for conservation_mode sysfs. Diagnosis recipe: `journalctl -b -u iwd | grep -E 'rfkill|status: 1|state,'` plus `journalctl -b -u NetworkManager` around the event.

### Intel GPU Metrics (nix-media)

`intel-gpu-tools` 2.2→2.3 changed output format. The awk parser in `hosts/nix-media/monitoring.nix` was updated to handle the new format. If metrics break after an update, check the parser.

### HM activation vs shell-written gtk ini files (yoga) — 2026-09-24, historical

HM's `gtk.*` module generates `~/.config/gtk-{3.0,4.0}/settings.ini` as store symlinks. The retired Lucid shell's `envtool.py` rewrote those files at every shell start via atomic rename (write-temp + `mv`), replacing the symlink with a real file; on the next boot the HM activation tried to back the real file up to `settings.ini.backup`, found a stale `.backup` from a previous activation, and **aborted the entire activation**: no `~/.config/systemd/user/` at all → the shell never started and `XCURSOR_THEME` was unset. One failed `checkLinkTargets` takes down every HM-managed file, so unrelated symptoms pile up. (Historical fix: `gtk.enable` was gated off the lucid attr; the gate died with lucid — `gtk.enable = true` unconditionally again since 2026-11-14, which matches what the niri/Noctalia attr already ran: Noctalia's templates paint via `noctalia.css` + gsettings and don't atomically rewrite the HM-owned ini files.)

If activation ever fails at boot again, check `journalctl -b -u home-manager-dk.service` first: whatever is missing downstream usually has this single root cause.

### libvirt default network: never compare `virsh net-dumpxml` to authored XML raw (fixed 2026-09-30)

`virsh net-dumpxml` emits libvirt's *canonical* XML — it injects `<uuid>` and the bridge `<mac>` and reformats whitespace — so a raw string compare against the authored store file in `modules/features/virtualization.nix` never matched. The old drift guard therefore destroy/redefined the `default` network at **every boot** (and on every nixpkgs-bump unit restart, which changes the unit hash). Destroying the network unplugs the NIC of any running guest without re-attaching it — "VMs randomly lose networking" (observed 2026-09); the guard sat inert until the multi-guest refactor added a second DHCP reservation, the first real XML change.

**Fix:** both sides are normalized before comparing (strip `<uuid>`/bridge `<mac>`, squeeze whitespace); a real drift while domains are running is **deferred** — never unplug a running guest — and a 6h timer re-runs the check (the oneshot has no `RemainAfterExit` on purpose: a timer cannot re-run an active unit); `net-start` errors are no longer swallowed. First diagnostic when guests lose networking: `journalctl -u libvirt-default-network -b` — a destroy/undefine/define triple with no config change means the normalization regressed. A legitimate drift (guest added/removed in Nix) may destroy the network once on the next boot with no VMs running — by design.

### libvirt firewall backend auto-flips with nftables (fixed 2026-09-30)

`virtualisation.libvirtd.firewallBackend` defaults to `nftables` as soon as `networking.nftables.enable = true` — enabling the host nftables firewall (2026-09-13) silently switched libvirt's firewall backend as well and broke the default network's NAT: guests still got DHCP ("connected") but had no internet. The backend is now pinned to `"iptables"` in `modules/features/virtualization.nix`; its iptables-nft rules live in separate `LIBVIRT_*` chains and coexist with `inet nixos-fw`, which only ever replaces its own table. Symptom if unpinned again: VM "connected, no internet" while `virsh net-dhcp-leases` shows a valid lease. First diagnostic: `cat /var/lib/libvirt/network.conf`.

### virbr0 guest→host traffic vs the nftables input chain (hardened 2026-10-03)

The second half of the 2026-09-30 NAT incident: `inet nixos-fw` has policy drop and only trusted lo/tailscale0, and an ACCEPT in libvirt's iptables-nft table cannot override another table's drop — so DHCP/DNS from the bridge never reached the host dnsmasq (guests showed "identifying → unidentified network"). The initial fix trusted `virbr0` wholesale (`firewall.trustedInterfaces`), which let the Windows guest reach **every** host service. Now `modules/features/virtualization.nix` opens exactly the two ports the default network needs via `firewall.extraInputRules` (udp/67 DHCP, udp+tcp/53 DNS on `iifname "virbr0"`); everything else from the bridge stays dropped. nftables-only — silently ignored under the iptables backend, where libvirt's own rules coexist anyway. Behavior is pinned by `tests/virbr0-firewall.nix` (`nix build .#nixosTests.x86_64-linux.virbr0-firewall`): a guest node on the same bridge must get a DHCP lease and DNS answers, and must NOT reach a canary host port. Symptom if the rules regress: guest "unidentified network" / no lease; first diagnostic `sudo nft list ruleset | grep virbr0`.

### spotify-spotx build fails after a nixpkgs bump — SpotX-Bash pin drift (laptops, added 2026-10-18)

`modules/features/spotify.nix` consumes `github:SpotX-Official/SpotX-Nix` with `nixpkgs.follows` — we build spotify-spotx against OUR nixpkgs' spotify, while the SpotX-Bash patch script rides SpotX-Nix's own lock (their bot re-aligns the two every ~6 h). If a nixpkgs bump ships a spotify newer than their currently-pinned SpotX-Bash supports, the spotify-spotx derivation fails the build loudly with `Nixpkgs Spotify X is newer than SpotX-Bash Y`. Fix: `nix flake update spotx-nix` (pulls their newer lock, which has the matching SpotX-Bash), re-stage `flake.lock`, rebuild. That is also why `spotx-nix` is deliberately NOT in `scripts/update-safe`'s input list — a blind update there could equally pull a SpotX-Bash ahead of a pinned-older nixpkgs; treat it like the other manual pins. `--premium`-style extra flags go through `features.spotify.spotxArgs` (build-time only; interactive/client-install options are rejected during a Nix build).


---

## Recovery Procedures

### Boot fails — "missing template snapshot"

`@blank` deleted or corrupted. From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs subvolume show /mnt/@          # check if @ still exists
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank  # recreate from @
umount /mnt
exit
```

### Boot fails — "not a read-only snapshot"

`@blank` exists but lost its read-only flag. From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs property set -ts /mnt/@blank ro true
umount /mnt
exit
```

### Boot fails — "missing required path"

A directory is missing from `@blank` (partition layout changed without template update). From initrd emergency shell:
```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs subvolume delete /mnt/@blank
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank
umount /mnt
exit
```

### General rule

Any error in the rollback script aborts the service → `OnFailure = "emergency.target"` → initrd emergency shell. `@` is never touched unless `@blank` passes all validations, so data is preserved.

---

## File Quick Reference

| Looking for... | Go to... |
|----------------|----------|
| How a host is built | `lib/mkHost.nix` |
| Boot configuration | `modules/core/boot.nix` |
| Desktop environment | `modules/features/desktop-gnome.nix` |
| niri session / Noctalia | `modules/features/desktop-niri.nix` + `home/niri.nix` + `home/noctalia.nix` |
| Theme/dark mode | `home/theme.nix` |
| Terminal/shell | `home/terminal.nix` |
| Browser config | `home/browsers.nix` |
| Spotify (SpotX-patched) | `modules/features/spotify.nix` |
| Windows VMs (virt-manager) | `modules/features/virtualization.nix` |
| Disk layout (yoga, latitude) | `hosts/<name>/disks.nix` |
| Docker containers | `hosts/nix-media/docker.nix` |
| Monitoring stack | `hosts/nix-media/monitoring.nix` |
| Media-server service ports | `modules/roles/media.nix` (`roles.media.ports` — consumed by docker binds, Caddy targets, Prometheus scrapes) |
| SSH hardening (key-only, mgmt LAN) | `modules/core/openssh.nix` + `profiles/laptop.nix` |
| CI pipeline | `.github/workflows/ci.yml` (push/PR gate) + `bump.yml` (weekly bump) |
| Nix settings/caches | `modules/core/nix.nix` |
| User configuration | `modules/core/users.nix` |
| Tailscale VPN | `modules/features/vpn.nix` |
| Secure Boot | `modules/features/secureboot.nix` |
| SOPS secrets | `modules/features/sops.nix` |
| Impermanence module | `modules/features/impermanence.nix` |
| Custom packages | `pkgs/` |
| Flake definition | `flake.nix` |
