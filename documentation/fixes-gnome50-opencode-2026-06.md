# Fixes: GNOME 50 Colloid Theme + OpenCode Provider Persistence

**Date:** 2026-06-11
**Status:** Implemented
**Last updated:** 2026-06-11

## Context

Two issues resolved during NixOS 26.05 + GNOME 50 upgrade:

1. **OpenCode provider drops** on reboot/rebuild — provider SDK npm packages in `~/.cache/opencode/` break when nix store paths change
2. **Colloid GTK theme** — nixpkgs version `2025-07-31` outdated, 12+ unreleased commits on `main` fix widget issues, no `--libadwaita` flag for GTK4 apps

Additionally: **Removed `nixpkgs-unstable`** input — all packages now come from stable 26.05 with custom overlays for colloid and fluent.

---

## Changes Implemented

### 1. Colloid Theme — GNOME 50 Compatibility

**Key finding:** The Colloid `install.sh` already handles GNOME 50 via fallback (`50 >= 48` → `48-0` styles). GNOME Shell theming works out of the box.

**What was done:**

| File | Change |
|------|--------|
| `pkgs/colloid-gtk-theme.nix` | **New file.** Custom derivation fetching git `main` (commit `fd805db`, Dec 2025). Adds `--libadwaita` flag for proper GTK4/Libadwaita theming. |
| `flake.nix` | Added nixpkgs overlay to use the custom colloid package |
| `home/theme.nix` | Uses `pkgs.colloid-gtk-theme.override { tweaks = [ "nord" ]; }` (overlaid package) |

**How it works:**
- The overlay replaces `pkgs.colloid-gtk-theme` with the custom derivation
- The `--libadwaita` flag installs GTK4 theme files to `$out/share/themes/<theme>/gtk-4.0/`
- The `switch-theme` script symlinks these to `~/.config/gtk-4.0/` at runtime

### 2. Fluent Icon Theme — Latest Fixes

**What was done:**

| File | Change |
|------|--------|
| `pkgs/fluent-icon-theme.nix` | **New file.** Custom derivation fetching git `main` (commit `8a99a6d`, Nov 2025). |
| `flake.nix` | Added to overlay alongside colloid |
| `home/theme.nix` | Uses `pkgs.fluent-icon-theme` (overlaid package) |

### 3. OpenCode Provider Persistence Fix

**Root cause:** Provider SDK packages (`@ai-sdk/openai-compatible`, etc.) are dynamically installed via npm to `~/.cache/opencode/`. On NixOS, these break when nix store paths change on rebuild.

**What was done:**

| File | Change |
|------|--------|
| `hosts/yoga/home.nix` | Migrated from `home.file` to `programs.opencode` module. Added `pkgs.opencode` with `LD_LIBRARY_PATH` fix. Added `opencode-cache-clean` systemd service. |
| `home/terminal.nix` | Removed redundant opencode package from `home.packages` (now handled by HM module). |

**How it works:**
- `programs.opencode` writes `~/.config/opencode/opencode.json` declaratively via `xdg.configFile`
- The `opencode-cache-clean` service runs on boot (Type=oneshot, WantedBy=default.target)
- It clears `~/.cache/opencode/node_modules/` so provider SDKs are rebuilt fresh
- Impermanence already persists all 4 required directories

### 4. Removed `nixpkgs-unstable`

**Why:** All packages previously using unstable are now either:
- Available in stable 26.05 (`opencode` 1.15.10, `ghostty` 1.3.1)
- Handled via custom overlays (colloid, fluent)

**What was done:**

| File | Change |
|------|--------|
| `flake.nix` | Removed `nixpkgs-unstable` input |
| `lib/mkHost.nix` | Removed `pkgsUnstable` from `commonArgs` |
| `hosts/yoga/home.nix` | Removed `pkgsUnstable` from function args, uses `pkgs.opencode` |
| `home/terminal.nix` | Removed `pkgsUnstable` from function args, uses `pkgs.ghostty` |
| `home/theme.nix` | Removed `pkgsUnstable` from function args, uses `pkgs.fluent-icon-theme` |

---

## Files Modified

```
flake.nix                          # Removed unstable input, added colloid + fluent overlays
lib/mkHost.nix                     # Removed pkgsUnstable
pkgs/colloid-gtk-theme.nix         # NEW: Custom derivation (git main + libadwaita)
pkgs/fluent-icon-theme.nix         # NEW: Custom derivation (git main)
hosts/yoga/home.nix                # programs.opencode + systemd service + removed pkgsUnstable
home/theme.nix                     # Uses overlaid pkgs for colloid + fluent
home/terminal.nix                  # Removed opencode package + removed pkgsUnstable
documentation/fixes-gnome50-opencode-2026-06.md  # This file
```

---

## Architecture

All packages now come from **stable NixOS 26.05** with two custom overlays:

| Package | Source | Reason |
|---------|--------|--------|
| `colloid-gtk-theme` | Custom overlay (git main) | GNOME 50 fixes + libadwaita support |
| `fluent-icon-theme` | Custom overlay (git main) | Latest icon additions |
| `opencode` | Stable 26.05 | v1.15.10 (sufficient) |
| `ghostty` | Stable 26.05 | v1.3.1 (same as unstable) |

### Adding unstable packages in the future

If you need a package not in stable, you can temporarily re-add the unstable input:

```nix
# flake.nix inputs
nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

# flake.nix outputs (in pkgs overlay)
(final: _prev: {
  some-package = inputs.nixpkgs-unstable.legacyPackages.${system}.some-package;
})
```

---

## Verification

After rebuilding, test:

### Theme
```bash
switch-theme dark
# Verify: GTK3 apps show Colloid-Dark-Nord
# Verify: GTK4 apps (Nautilus, Settings) show Colloid theme
# Verify: GNOME Shell panel/overview styled
# Verify: darkman auto-switching works at sunset/sunrise
```

### OpenCode
```bash
# Rebuild NixOS
sudo nixos-rebuild switch --flake ~/nixos-config

# Launch OpenCode
opencode

# Verify: OpenRouter provider connects
# Verify: Models listed correctly
# Verify: Settings persist after reboot
```

---

## Troubleshooting

### Theme not applying to GTK4 apps
- Check `~/.config/gtk-4.0/` has symlinks: `ls -la ~/.config/gtk-4.0/`
- Re-run: `switch-theme dark`

### OpenCode provider still dropping
- Check cache was cleaned: `ls ~/.cache/opencode/node_modules/` (should be empty or fresh)
- Check systemd service: `systemctl --user status opencode-cache-clean`
- Manual clean: `rm -rf ~/.cache/opencode/node_modules`

### Colloid/Fluent hash mismatch
If the source hash changes (new commits on main):
```bash
nix-prefetch-github vinceliuice Colloid-gtk-theme --rev <new-commit>
nix-prefetch-github vinceliuice Fluent-icon-theme --rev <new-commit>
# Update hash in pkgs/colloid-gtk-theme.nix or pkgs/fluent-icon-theme.nix
```

---

## Lint Fixes Applied

1. **statix [20]**: Repeated `programs` keys in `hosts/yoga/home.nix` — consolidated into single `programs = { ... }` block
2. **deadnix**: Unused `prev` lambda argument in `flake.nix` overlay — renamed to `_prev`

---

## Future Maintenance

- **Colloid:** When a new release includes GNOME 50 support, consider reverting to the nixpkgs package. Check https://github.com/vinceliuice/Colloid-gtk-theme/releases
- **Fluent:** When a new release is made, consider reverting to the nixpkgs package. Check https://github.com/vinceliuice/Fluent-icon-theme/releases
- **OpenCode:** The HM `programs.opencode` module is maintained upstream. Update with home-manager releases.
