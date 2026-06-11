# Fixes: GNOME 50 Colloid Theme + OpenCode Provider Persistence

**Date:** 2026-06-11
**Status:** Implemented
**Last updated:** 2026-06-11

## Context

Issues resolved during NixOS 26.05 + GNOME 50 upgrade:

1. **OpenCode provider drops** on reboot/rebuild
2. **Colloid GTK theme** — nixpkgs version outdated, needs GNOME 50 fixes
3. **Removed `nixpkgs-unstable`** — all packages from stable 26.05

---

## OpenCode Provider Investigation

### What we know (evidence-based)

| Check | Finding |
|-------|---------|
| `opencode.json` symlink | Identical to nix store — OpenCode does NOT write to it |
| `auth.json` | Persists with API keys for OpenRouter + OpenCode |
| `kv.json` | Has `"openrouter_warning": true` — persists across rebuilds |
| `model.json` | Shows `providerID: "opencode"` — built-in free models, NOT OpenRouter |
| All logs | Every entry shows `providerID=opencode` — OpenRouter never used |
| `~/.cache/opencode/node_modules/` | EMPTY — auth SDK packages not installed |

### What was tried (and why it was wrong)

**Attempt 1: `home.file` instead of `programs.opencode.settings`**

Claimed fix: "Use `home.file` to create a real writable file instead of a symlink."

**Why it's wrong:** `home.file."<path>".text` and `xdg.configFile."<path>".text` are functionally identical. Both call `pkgs.writeText` internally and create a symlink to the nix store. There is no "copy mode." The resulting file at `~/.config/opencode/opencode.json` is a symlink either way.

**Proof:**
```bash
$ diff ~/.config/opencode/opencode.json $(readlink ~/.config/opencode/opencode.json)
# No output — files are identical
$ touch ~/.config/opencode/opencode.json
touch: cannot create file: Permission denied
```

**Conclusion:** The symlink being read-only is irrelevant because OpenCode doesn't write to `opencode.json` at all.

### Current hypothesis

The `opencode-cache-clean` systemd service was deleting `~/.cache/opencode/node_modules/` on every boot. These packages (`opencode-copilot-auth`, `opencode-anthropic-auth`) are needed by OpenCode to initialize provider authentication. Deleting them forces a re-download on every boot, which can:

1. Fail silently if network is unavailable during boot
2. Race with OpenCode startup
3. Cause provider initialization to fall back to built-in models

**Action taken:** Removed the `opencode-cache-clean` service.

### What we still don't know

1. **Where does `/connect` store its state?** — Not in `opencode.json` (proven). Likely in the SQLite database (`opencode-stable.db`) or `kv.json`.

2. **Why does `kv.json` have `"openrouter_warning": true`?** — This flag persists and might prevent OpenRouter from being used. Needs investigation.

3. **Why does `model.json` show `providerID: "opencode"` despite config saying `openrouter`?** — Either OpenRouter initialization fails and falls back, or the user has been using built-in models all along.

### Recommended next steps

1. **After rebuild, test:** Run `opencode`, run `/connect`, quit, rebuild, relaunch. Does `/connect` persist?

2. **If not, check:**
   ```bash
   # Check if openrouter_warning is the blocker
   cat ~/.local/state/opencode/kv.json | jq '.openrouter_warning'
   
   # Check database for provider state
   sqlite3 ~/.local/share/opencode/opencode-stable.db ".tables"
   
   # Check if node_modules rebuilt properly after boot
   ls -la ~/.cache/opencode/node_modules/
   ```

3. **If `openrouter_warning` is `true`:** Try deleting it:
   ```bash
   # Remove the warning flag
   jq 'del(.openrouter_warning)' ~/.local/state/opencode/kv.json > /tmp/kv.json && mv /tmp/kv.json ~/.local/state/opencode/kv.json
   ```

4. **If node_modules are missing:** The cache-clean service removal should fix this. If not, check if OpenCode can install packages on startup.

---

## Changes Made

### Files Modified

| File | Change |
|------|--------|
| `flake.nix` | Removed `nixpkgs-unstable`, added colloid + fluent overlays |
| `lib/mkHost.nix` | Removed `pkgsUnstable` |
| `pkgs/colloid-gtk-theme.nix` | NEW: Custom derivation (git main + libadwaita) |
| `pkgs/fluent-icon-theme.nix` | NEW: Custom derivation (git main) |
| `hosts/yoga/home.nix` | `programs.opencode` (package + settings), removed cache-clean service |
| `home/theme.nix` | Uses overlaid `pkgs` for colloid + fluent |
| `home/terminal.nix` | Uses `pkgs.ghostty` (stable) |

### OpenCode config approach

```nix
# Package install + declarative settings via programs.opencode
programs.opencode = {
  enable = true;
  package = pkgs.opencode.overrideAttrs ...;
  settings = { ... };
};

# Config is a symlink to nix store (read-only) — this is FINE because
# OpenCode does NOT write to opencode.json. /connect state is stored
# elsewhere (database, kv.json, or auth.json).
```

---

## Verification

After rebuilding, test:

### OpenCode
```bash
sudo nixos-rebuild switch --flake ~/nixos-config
opencode
> /connect    # Connect to OpenRouter
# Quit, rebuild, relaunch — /connect should persist
```

### Theme
```bash
switch-theme dark
# Verify GTK3 + GTK4 apps, GNOME Shell, darkman
```

---

## Architecture: `xdg.configFile` vs `home.file`

Both create **symlinks to the nix store**. Neither creates a writable file.

| Mechanism | Creates | Writable | Use case |
|-----------|---------|----------|----------|
| `xdg.configFile` | Symlink | ❌ | Declarative config |
| `home.file` | Symlink | ❌ | Declarative config |

**If an app needs to write to its config at runtime**, the correct approach is `home.activation` with an existence guard:

```nix
home.activation.opencode-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
  _cfg="${config.xdg.configHome}/opencode/opencode.json"
  if [[ ! -f "$_cfg" ]]; then
    mkdir -p "$(dirname "$_cfg")"
    printf '%s' '${builtins.toJSON { ... }}' > "$_cfg"
  fi
'';
```

This writes a real file exactly once, then OpenCode owns it. However, this is NOT needed for OpenCode because it doesn't write to `opencode.json`.

---

## Lint Fixes Applied

1. **statix [20]**: Repeated `programs` keys — consolidated
2. **deadnix**: Unused `prev` — renamed to `_prev`
3. **deadnix**: Unused `finalAttrs` — removed from colloid package
4. **nixfmt**: Colloid package reformatted

---

## Future Maintenance

- **Colloid:** Revert to nixpkgs when GNOME 50 support is released. Check https://github.com/vinceliuice/Colloid-gtk-theme/releases
- **Fluent:** Revert to nixpkgs when new release is made. Check https://github.com/vinceliuice/Fluent-icon-theme/releases
- **OpenCode:** The `programs.opencode` module is useful for package management. Config symlink is fine — OpenCode doesn't write to it.
