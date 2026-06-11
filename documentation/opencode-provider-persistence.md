# OpenCode Provider Persistence — Investigation & Fixes

**Date:** 2026-06-11
**Status:** Partially resolved
**Hosts affected:** yoga, latitude
**Environment:** NixOS 26.05, GNOME 50, Impermanence (yoga), Home Manager release-26.05

---

## Problem

After `nixos-rebuild switch` or reboot, the **OpenCode built-in provider** requires re-authentication via `/connect`. The **OpenRouter provider persists correctly** — only the OpenCode provider connection is lost.

---

## NixOS Configuration

OpenCode is configured via Home Manager's `programs.opencode` module:

```nix
programs.opencode = {
  enable = true;
  package = pkgs.opencode.overrideAttrs (previousAttrs: {
    postFixup = (previousAttrs.postFixup or "") + ''
      wrapProgram $out/bin/opencode \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  });
  settings = {
    model = "openrouter/deepseek/deepseek-v4-flash";
    small_model = "openrouter/mistralai/mistral-small-3.2-24b-instruct";
    provider = {
      openrouter = {
        models = {
          "deepseek/deepseek-v4-flash" = { };
          "deepseek/deepseek-v4-pro" = {
            options = {
              provider = {
                order = [ "deepseek" ];
                allow_fallbacks = true;
              };
            };
          };
        };
      };
    };
    permission = {
      edit = "ask";
      bash = {
        "*" = "ask";
        "git status" = "allow";
        "git diff *" = "allow";
        "rm -rf *" = "deny";
      };
    };
  };
};
```

### Impermanence Directories (yoga, all persisted)

```nix
home.persistence."/persist" = {
  directories = [
    { directory = ".local/share/opencode"; mode = "0700"; }
    { directory = ".local/state/opencode"; mode = "0700"; }
    { directory = ".cache/opencode"; mode = "0700"; }
    { directory = ".config/opencode"; mode = "0700"; }
  ];
};
```

---

## Diagnostic Findings

| Check | Finding |
|-------|---------|
| `opencode.json` symlink | Identical to nix store — OpenCode does NOT write to it |
| `auth.json` | Persists with API keys for both OpenRouter + OpenCode |
| `kv.json` | Has `"openrouter_warning": true` — persists across rebuilds |
| `model.json` | Shows `providerID: "opencode"` — built-in free models, NOT OpenRouter |
| All logs | Every entry shows `providerID=opencode` — OpenRouter never used in logs |
| `~/.cache/opencode/node_modules/` | EMPTY — auth SDK packages not installed |
| `~/.config/opencode/node_modules/@opencode-ai/` | Contains `plugin/` and `sdk/` |

### Key evidence

**`opencode.json` is read-only (by design) — irrelevant:**

```bash
$ diff ~/.config/opencode/opencode.json $(readlink ~/.config/opencode/opencode.json)
# No output — files are identical

$ touch ~/.config/opencode/opencode.json
touch: cannot create file: Permission denied
```

OpenCode does NOT write to `opencode.json` at runtime. The symlink being read-only is not the cause.

**`auth.json` persists correctly:**

```bash
$ cat ~/.local/share/opencode/auth.json
{
  "openrouter": { "type": "api", "key": "sk-or-v1-..." },
  "opencode": { "type": "api", "key": "sk-..." }
}
```

**`kv.json` has persistent warning flag:**

```bash
$ cat ~/.local/state/opencode/kv.json
{
  "openrouter_warning": true,
  "tips_hidden": true,
  "theme": "nord",
  ...
}
```

---

## What Was Tried

### Attempt: `home.file` instead of `programs.opencode.settings`

**Claimed fix:** Use `home.file` to create a real writable file.

**Why it's wrong:** `home.file."<path>".text` and `xdg.configFile."<path>".text` are functionally identical. Both call `pkgs.writeText` internally and create a symlink to the nix store. There is no "copy mode."

**Reverted.**

---

## Current Hypothesis

The `opencode-cache-clean` systemd service was deleting `~/.cache/opencode/node_modules/` on every boot. These packages (`opencode-copilot-auth`, `opencode-anthropic-auth`) are needed by OpenCode to initialize provider authentication. Deleting them forces a re-download on every boot, which can:

1. Fail silently if network is unavailable during boot
2. Race with OpenCode startup
3. Cause provider initialization to fall back to built-in models

**Action taken:** Removed the `opencode-cache-clean` service.

---

## `xdg.configFile` vs `home.file` Architecture

Both create **symlinks to the nix store**. Neither creates a writable file.

| Mechanism | Creates | Writable | Use case |
|-----------|---------|----------|----------|
| `xdg.configFile` | Symlink | No | Declarative config |
| `home.file` | Symlink | No | Declarative config |

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

## Open Questions

1. **Where does `/connect` store its state?** — Not in `opencode.json` (proven). Likely in the SQLite database (`opencode-stable.db`) or `kv.json`.

2. **Why does `kv.json` have `"openrouter_warning": true`?** — This flag persists and might prevent OpenRouter from being used.

3. **Why does `model.json` show `providerID: "opencode"` despite config saying `openrouter`?** — Either OpenRouter initialization fails and falls back, or the user has been using built-in models all along.

---

## Recommended Next Steps

1. **After rebuild, test:**
   ```bash
   opencode
   > /connect    # Connect to OpenRouter
   # Quit, rebuild, relaunch — /connect should persist
   ```

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
   jq 'del(.openrouter_warning)' ~/.local/state/opencode/kv.json > /tmp/kv.json && mv /tmp/kv.json ~/.local/state/opencode/kv.json
   ```

4. **If node_modules are missing:** The cache-clean service removal should fix this. If not, check if OpenCode can install packages on startup.

---

## Reproduction Steps

1. Configure OpenCode with `programs.opencode` in Home Manager
2. Run `nixos-rebuild switch`
3. Launch OpenCode
4. Run `/connect` to authenticate with the OpenCode built-in provider
5. Verify both providers work (OpenRouter + OpenCode)
6. Quit OpenCode
7. Run `nixos-rebuild switch` again
8. Launch OpenCode — OpenRouter works, OpenCode provider requires `/connect` again

---

## Related: `libstdc++.so.6` Runtime Fix

A separate issue — `libstdc++.so.6` missing at runtime (file watcher failure) —
was fixed via `overrideAttrs` with `LD_LIBRARY_PATH`. See
[upgrade-26.05.md → opencode libstdc++ fix](upgrade-26.05.md#7-opencode-libstdcso6-missing-nixos)
for details.


