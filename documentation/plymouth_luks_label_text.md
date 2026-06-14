# Plymouth LUKS Prompt — Remove Text Below Password Input

## Affected Hosts

- **yoga** — bgrt theme, silent boot, LUKS (Disko)
- **latitude** — bgrt theme, silent boot, LUKS (legacy)
- Any host with `core.boot.silent = true` + `boot.plymouth.enable = true` + LUKS encryption

## Problem Statement

The graphical Plymouth LUKS password prompt displays text below the password input
field. This text includes the LUKS device name and may contain NixOS store paths
(e.g. `/nix/store/...`). The text is rendered by the `label-freetype.so` Plymouth
plugin, which was added to the initrd upstream (Fedora 42 / NixOS 26.05) to show
device-name labels during passphrase entry.

The text is:

- **Unwanted** — the bgrt theme's visual design does not need a text label
- **Ugly** — contains raw device descriptions or store paths
- **Inconsistent with prior behaviour** — Fedora 41 and older NixOS did not show this text

### Upstream context

- [Fedora Bug 2356893](https://bugzilla.redhat.com/show_bug.cgi?id=2356893) — "Text Appearing under LUKS decryption box"
- [Fedora Discussion](https://discussion.fedoraproject.org/t/please-enter-passphrase-for-disk-has-returned/150626/3)
- [Plymouth MR 357](https://gitlab.freedesktop.org/plymouth/plymouth/-/merge_requests/357) — partial fix (strips colon, adds padding) but text still appears

## Root Cause

The NixOS plymouth module (`nixos/modules/system/boot/plymouth.nix:240-251`)
generates a `plymouth-initrd-plugins` derivation that copies **all** `*.so` files
from the `themesEnv` into the initrd:

```nix
cp ${themesEnv}/lib/plymouth/*.so $out
```

This includes `label-freetype.so`, which renders the "question" text from
`systemd-tty-ask-password-agent` below the password entry field. The two-step
plugin (used by bgrt/spinner themes) renders the graphical password entry
independently via `ply_entry_*` — the label plugin is only needed for text
rendering.

## Fix

**Exclude `label-freetype.so` and `label-pango.so` from the initrd plugins.**

### Implementation (`modules/core/boot.nix`)

Added inside the `boot.initrd.systemd` block, wrapped in `lib.mkIf cfg.silent`:

```nix
contents = lib.mkIf cfg.silent {
  "/etc/plymouth/plugins".source = lib.mkForce (
    let
      pluginSource = pkgs.buildEnv {
        name = "plymouth-all-plugins";
        paths = [ config.boot.plymouth.package ] ++ config.boot.plymouth.themePackages;
      };
    in
    pkgs.runCommand "plymouth-initrd-plugins-nolabel" { } ''
      mkdir -p $out/renderers
      for f in ${pluginSource}/lib/plymouth/*.so; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
          label-*) ;;
          *) cp "$f" "$out/" ;;
        esac
      done
      for f in ${pluginSource}/lib/plymouth/renderers/*.so; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
          x11.so) ;;
          *) cp "$f" "$out/renderers/" ;;
        esac
      done
    ''
  );
};
```

### Key details

| Aspect | Detail |
|--------|--------|
| `lib.mkForce` | Required to override the NixOS plymouth module's `contents` value |
| `lib.mkIf cfg.silent` | No-op on hosts without Plymouth (e.g. nix-media) |
| `label-*` filter | Skips both `label-freetype.so` and `label-pango.so` |
| `[ -e "$f" ] \|\| continue` | Guards against empty globs passing literal strings to `basename` |
| `x11.so` filter | X11 renderer is useless in initrd (upstream also removes it) |
| `pluginSource` | Used for both plugins and renderers (consistent sourcing) |

### Why the password entry still works

The `two-step.so` plugin renders the graphical password entry using
`ply_entry_*` functions from `libply-splash-graphics.so` (a core library).
The label plugin provides `ply_label_*` functions for text rendering. If
no label plugin is loaded, `ply_label_show()` is a no-op — the password
entry widget continues to function normally.

### Tradeoffs

- **Pro**: Clean removal of all text below the LUKS input field
- **Pro**: Matches pre-Fedora-42 / pre-NixOS-26.05 behaviour
- **Con**: No device name shown during LUKS unlock (user won't see "cryptroot")
- **Con**: Overrides NixOS module internals — needs maintenance if upstream changes

## Verification

After rebuilding, check the following:

```bash
# 1. label-freetype.so must NOT be in the initrd
sudo lsinitrd /nix/store/*-initrd-linux-*/initrd 2>/dev/null | grep label
# Expected: no output

# 2. two-step.so must still be present
sudo lsinitrd /nix/store/*-initrd-linux-*/initrd 2>/dev/null | grep two-step
# Expected: two-step.so

# 3. Boot should show graphical Plymouth with password field but no text below it
```

## Configuration History

| Date | Commit | label-freetype in initrd | Text below input | Notes |
|------|--------|:---:|:---:|-------|
| Pre-F42 | — | no | no | Label plugin not included in initrd by default |
| F42 / NixOS 26.05 | upstream | **yes** | **yes** | Added for device-name display |
| Current | boot.nix change | **no** | **no** | Filtered out by custom derivation |

## References

- [Fedora Bug 2356893](https://bugzilla.redhat.com/show_bug.cgi?id=2356893) — upstream report
- [Plymouth MR 357](https://gitlab.freedesktop.org/plymouth/plymouth/-/merge_requests/357) — partial upstream fix
- [Plymouth Issue 294](https://gitlab.freedesktop.org/plymouth/plymouth/-/issues/294) — upstream discussion
- [plymouth_luks_issue.md](plymouth_luks_issue.md) — related: amdgpu/simpledrm race on yoga
