# OpenCode Provider Connection Drops After NixOS Rebuild

## Environment

- **OS:** NixOS 26.05 (stable)
- **OpenCode version:** 1.15.13 (stable channel)
- **Home Manager:** release-26.05
- **Impermanence:** Yes (root wiped on reboot, `/persist` mounted)
- **Desktop:** GNOME 50

## Problem Description

After running `nixos-rebuild switch` or rebooting, the **OpenCode built-in provider** requires re-authentication via `/connect`. The **OpenRouter provider persists correctly** — only the OpenCode provider connection is lost.

The user must run `/connect` for the OpenCode provider after each rebuild/reboot.

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

### Impermanence Directories (all persisted)

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

## Diagnostic Findings

### 1. opencode.json is a read-only symlink (by design)

```
~/.config/opencode/opencode.json -> /nix/store/.../opencode.json
```

Home Manager's `xdg.configFile` creates symlinks to the nix store. This is expected behavior.

**However:** A diff between the runtime file and the nix store target shows **no differences**. OpenCode does NOT write to `opencode.json` at runtime.

```bash
$ diff ~/.config/opencode/opencode.json $(readlink ~/.config/opencode/opencode.json)
# No output — files are identical

$ touch ~/.config/opencode/opencode.json
touch: cannot create file: Permission denied
```

### 2. auth.json persists correctly

```bash
$ cat ~/.local/share/opencode/auth.json
{
  "openrouter": {
    "type": "api",
    "key": "sk-or-v1-..."
  },
  "opencode": {
    "type": "api",
    "key": "sk-..."
  }
}
```

The file exists, is readable, and contains valid API keys. It persists across reboots via impermanence.

### 3. kv.json has persistent warning flag

```bash
$ cat ~/.local/state/opencode/kv.json
{
  "openrouter_warning": true,
  "tips_hidden": true,
  "theme": "nord",
  ...
}
```

The `openrouter_warning: true` flag persists across rebuilds. This may be preventing OpenRouter from being used.

### 4. model.json shows built-in provider, not OpenRouter

```bash
$ cat ~/.local/state/opencode/model.json
{
  "recent": [
    { "providerID": "opencode", "modelID": "deepseek-v4-flash-free" },
    { "providerID": "opencode", "modelID": "mimo-v2.5-free" },
    { "providerID": "opencode", "modelID": "minimax-m3-free" }
  ],
  "variant": {
    "opencode/mimo-v2.5-free": "high",
    "opencode/deepseek-v4-flash-free": "max"
  }
}
```

Despite the config specifying `openrouter/deepseek/deepseek-v4-flash`, recent model usage is `providerID: "opencode"` (built-in free models). This is expected — the user uses **both** providers.

### 5. All logs show built-in provider

Every log entry shows:
```
providerID=opencode modelID=deepseek-v4-flash-free
```

OpenRouter is not shown in these logs — the user was using the OpenCode built-in provider at the time.

### 6. node_modules in cache is empty

```bash
$ ls ~/.cache/opencode/node_modules/
# Empty or missing

$ cat ~/.cache/opencode/package.json
{
  "dependencies": {
    "opencode-copilot-auth": "0.0.12",
    "opencode-anthropic-auth": "0.0.8"
  }
}
```

The auth SDK packages for Copilot and Anthropic are defined but not installed. Note: These are NOT OpenRouter packages — OpenRouter uses a standard API key, not OAuth.

### 7. node_modules in config directory exists

```bash
$ ls ~/.config/opencode/node_modules/@opencode-ai/
plugin/  sdk/
```

The plugin SDK is installed in the config directory (different from the cache directory).

## Open Questions

1. **Where does the OpenCode built-in provider store its connection state?** OpenRouter persists (API key in auth.json), but the OpenCode provider has additional state beyond the API key that gets lost.

2. **What is `openrouter_warning` and how is it set?** This flag persists. Since OpenRouter works fine, it may be unrelated to the issue.

3. **Why does only the OpenCode built-in provider drop?** Both providers have API keys in `auth.json`, which persists. The OpenCode provider must store additional connection state somewhere that doesn't survive rebuilds.

4. **Does the OpenCode provider use a session token or similar ephemeral state?** If so, where is it stored?

## What Was Tried

### Attempt: `home.file` instead of `programs.opencode.settings`

**Claimed fix:** Use `home.file` to create a real writable file.

**Why it's wrong:** `home.file."<path>".text` and `xdg.configFile."<path>".text` are functionally identical. Both create symlinks to the nix store. There is no "copy mode."

**Reverted.**

## Reproduction Steps

1. Configure OpenCode with `programs.opencode` in Home Manager
2. Run `nixos-rebuild switch`
3. Launch OpenCode
4. Run `/connect` to authenticate with the OpenCode built-in provider
5. Verify both providers work (OpenRouter + OpenCode)
6. Quit OpenCode
7. Run `nixos-rebuild switch` again
8. Launch OpenCode — OpenRouter works, OpenCode provider requires `/connect` again

## Requested Help

- Where does the OpenCode built-in provider store its connection/authentication state beyond the API key in `auth.json`?
- What additional state does the OpenCode provider require that doesn't survive a NixOS rebuild?
- Is there a session token, cache, or ephemeral file the OpenCode provider uses that might not be persisted?
- Are there known issues with OpenCode's built-in provider on NixOS with impermanence?
