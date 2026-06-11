# NixOS 25.11 → 26.05 Upgrade

Upgrade record for all three hosts: **yoga**, **latitude**, **nix-media**.

## Overview

NixOS 26.05 "Yarara" was released 2026-05-30. This document covers every
configuration change required to upgrade from 25.11 "Xantusia" to 26.05.

Key 26.05 changes relevant to this config:

| Change | Impact on this config |
|--------|----------------------|
| systemd Stage 1 is now the default initrd | No migration — already using `boot.initrd.systemd.enable = true` |
| Bash `nixos-rebuild` removed | No migration — `system.rebuild.enableNg` was never set |
| dbus-broker is now the default D-Bus | Requires reboot after first switch |
| GCC 14 → 15 | May affect out-of-tree kernel modules (`ryzen-smu`) |
| GNOME 50 "Tokyo" | `gdm.wayland` option removed (Wayland is mandatory) |
| `services.resolved.extraConfig` removed | Migrated to `services.resolved.settings` |
| `programs.adb` removed | Replaced with `pkgs.android-tools` in systemPackages |
| Grafana `secret_key` no longer has a default | Hard-coded legacy key in nix-media monitoring |
| `fastfetchMinimal` renamed | Changed to `fastfetch.minimal` |
| `nixfmt-rfc-style` renamed | Changed to `nixfmt` |

## Flake Input Changes

### `flake.nix`

| Input | Before (25.11) | After (26.05) |
|-------|----------------|---------------|
| `nixpkgs` | `github:nixos/nixpkgs/nixos-25.11` | `github:nixos/nixpkgs/nixos-26.05` |
| `home-manager` | `github:nix-community/home-manager/release-25.11` | `github:nix-community/home-manager/release-26.05` |
| Formatter | `pkgs.nixfmt-rfc-style` | `pkgs.nixfmt` |

All other inputs (`lanzaboote`, `lix`, `lix-module`, `sops-nix`, `disko`,
`impermanence`, `winapps`, `preload-ng`, `nixos-hardware`) track `master` and
were updated via `nix flake update`.

### `flake.lock` — Updated Inputs

| Input | Old revision | New revision |
|-------|-------------|-------------|
| `nixpkgs` | `25f5383` (2026-05-26) | `bd0ff2d` (2026-06-08) |
| `home-manager` | `3ee51fb` (2026-05-23) | `d899b01` (2026-06-10) |
| `lix` | `c64fbc` (2026-05-27) | `ab149a6` (2026-06-09) |
| `disko` | `115e521` (2026-06-01) | `24fed06` (2026-06-08) |
| `nixos-hardware` | `4ed851c` (2026-06-01) | `32c2cd9` (2026-06-09) |
| `nixpkgs-unstable` | `331800d` (2026-05-31) | `a799d3e` (2026-06-06) |
| `winapps` | `3c1e7e1` (2026-06-02) | `abc2c3d` (2026-06-07) |

## Breaking Changes Fixed

### 1. `services.resolved.extraConfig` → `services.resolved.settings`

**File:** `modules/core/networking.nix`  
**Affects:** All hosts (yoga, latitude, nix-media)

NixOS 26.05 removed the `extraConfig` string option for systemd-resolved.
Configuration must now use the structured `settings` attrset.

**Before:**

```nix
services.resolved = lib.mkIf (cfg.dns == "systemd-resolved") {
  enable = true;
  extraConfig = ''
    DNSStubListener=yes
    Cache=yes
    CacheFromLocalhost=yes
    DNSOverTLS=no
  '';
};
```

**After:**

```nix
services.resolved = lib.mkIf (cfg.dns == "systemd-resolved") {
  enable = true;
  settings = {
    Resolve = {
      DNSStubListener = "yes";
      Cache = "yes";
      CacheFromLocalhost = "yes";
      DNSOverTLS = "no";
    };
  };
};
```

**Why:** The `extraConfig` INI string was replaced by a typed Nix attrset
(`services.resolved.settings`) that maps directly to resolved.conf sections.
This provides validation at eval time instead of runtime.

### 2. `services.displayManager.gdm.wayland` removed

**File:** `modules/features/desktop-gnome.nix`  
**Affects:** yoga, latitude (hosts with GNOME desktop)

GNOME 50 is Wayland-only. The `gdm.wayland` option was removed because
disabling it is no longer supported.

**Before:**

```nix
gdm = {
  enable = true;
  wayland = true;
};
```

**After:**

```nix
gdm = {
  enable = true;
};
```

**Why:** GNOME 50 dropped X11 session support entirely. GDM always starts
a Wayland session; the option to choose X11 no longer exists.

### 3. `programs.adb` removed

**File:** `modules/core/users.nix`  
**Affects:** All hosts

systemd 258 (included in 26.05) handles uaccess rules automatically for USB
devices. The `programs.adb` option and `adbusers` group are no longer needed.
The `adb` command itself is provided by `pkgs.android-tools`.

**Before:**

```nix
programs = {
  # ...
  adb.enable = lib.mkDefault true;
};
```

**After:**

```nix
programs = {
  # ... (adb.enable removed)
};

environment.systemPackages = [ pkgs.android-tools ];
```

The `adbusers` group in `users.users.${mainUser}.extraGroups` was left in
place — it is harmless and removing it would require re-evaluating group
membership across all hosts.

**Why:** systemd 258's `uaccess` handling makes the `adbusers` group
unnecessary. The `programs.adb` module was removed from nixpkgs. The `adb`
binary is now just a regular package.

### 4. Grafana `secret_key` required

**File:** `hosts/nix-media/monitoring.nix`  
**Affects:** nix-media only

NixOS 26.05 removed the default `secret_key` for Grafana. It must now be
explicitly set.

**Change:**

```nix
security = {
  admin_user = "admin";
  secret_key = "SW2YcwTIb9zpOOhoPsMm";  # added — legacy default
  allow_embedding = false;
  # ...
};
```

The hard-coded value `SW2YcwTIb9zpOOhoPsMm` is Grafana's former built-in
default. This is safe for this setup because Grafana on nix-media does not
store session tokens or encrypted data that depends on key rotation. If that
changes, migrate to a SOPS-managed secret.

**Why:** Grafana 11.x (packaged in 26.05) requires an explicit `secret_key`
for encryption operations. The old default was removed as a security measure.

### 5. `fastfetchMinimal` → `fastfetch.minimal`

**Files:** `hosts/nix-media/default.nix`, `home/terminal.nix`  
**Affects:** All hosts

The `fastfetchMinimal` attribute was renamed to `fastfetch.minimal` in
nixpkgs 26.05.

**Before:**

```nix
pkgs.fastfetchMinimal
```

**After:**

```nix
pkgs.fastfetch.minimal
```

**Why:** Nixpkgs convention moved variant packages under the main package
attribute as sub-attributes (e.g. `fastfetch.minimal`, `fastfetch.full`).

### 6. `nixfmt-rfc-style` → `nixfmt`

**File:** `flake.nix`  
**Affects:** Build checks only

The formatter and CI check were updated to use the canonical package name.

**Before:**

```nix
formatter.${system} = pkgs.nixfmt-rfc-style;

checks.${system} = {
  nixfmt = pkgs.runCommand "nixfmt-check" {
    buildInputs = [ pkgs.nixfmt-rfc-style ];
  } "find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out";
};
```

**After:**

```nix
formatter.${system} = pkgs.nixfmt;

checks.${system} = {
  nixfmt = pkgs.runCommand "nixfmt-check" {
    buildInputs = [ pkgs.nixfmt ];
  } "find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out";
};
```

**Why:** Nixpkgs 25.11 renamed `nixfmt-rfc-style` to `nixfmt` (the
RFC-style formatter became the default). The old name is a deprecated alias
that may be removed in 26.11.

### 7. opencode `libstdc++.so.6` missing (NixOS)

**File:** `home/terminal.nix`  
**Affects:** yoga, latitude (hosts with opencode in home.packages)

opencode is compiled with Bun, which loads a native file-watcher module at
runtime that depends on `libstdc++.so.6`. NixOS does not include this library
in standard paths, so the file watcher fails on every startup:

```
ERROR service=file.watcher error=libstdc++.so.6: cannot open shared object file
```

This is a known NixOS issue ([opencode #462](https://github.com/anomalyco/opencode/issues/462))
caused by Bun's compilation bundling a dynamic `libstdc++` dependency. It
persists across opencode versions (1.10 → 1.15.x → 1.17.x) because it is a
build artifact, not a version-specific bug.

**Change:**

```nix
home.packages = [
  # ...
  (pkgs.opencode.overrideAttrs (previousAttrs: {
    postFixup = (previousAttrs.postFixup or "") + ''
      wrapProgram $out/bin/opencode \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  }))
];
```

**Why:** Wrapping the binary with `LD_LIBRARY_PATH` pointing to
`stdenv.cc.cc.lib` (which provides `libstdc++.so.6`) resolves the missing
library error at runtime. Using `overrideAttrs` with `postFixup` is the
standard NixOS pattern for injecting runtime library paths into packaged
binaries.

### 8. Docker `docker-28.5.2` marked insecure (nix-media CI)

**File:** `hosts/nix-media/docker.nix`  
**Affects:** nix-media only (CI builds)

NixOS 26.05 marked `docker_28` as insecure (unmaintained since November 2025).
The nix-media host uses `virtualisation.docker.enable = true`, which defaults
`package` to `pkgs.docker`. When the CI runs `nix flake update`, the latest
nixpkgs may resolve `pkgs.docker` to `docker-28.5.2`, causing evaluation to
fail:

```
error: Package 'docker-28.5.2' ... is marked as insecure, refusing to evaluate.
  docker_28 has been unmaintained since November 2025, use docker_29 or newer instead
```

**Change:**

```nix
virtualisation = {
  docker = {
    enable = true;
    package = pkgs.docker_29;   # added — avoids docker-28 insecure evaluation
    # ...
  };
};
```

**Why:** Pinning to `pkgs.docker_29` explicitly bypasses the insecure default.
This is an interim fix — when nix-media is fully upgraded to 26.05, the default
`pkgs.docker` will already be docker 29 and the pin can be removed. The
`docker_29` attribute exists in both 25.11 and 26.05, so it is safe to use
during the transition.

## Adopted 26.05 Defaults

These warnings were resolved by explicitly setting the new 26.05 defaults,
silencing the stateVersion deprecation notices.

### `gtk.gtk4.theme` set to `null`

**File:** `home/theme.nix`

The default changed from `config.gtk.theme` to `null`. Setting `null` is
correct for this config because the darkman `switch-theme` script manages
GTK4 theming at runtime via gsettings + manual symlink creation. Home-manager
should not interfere.

**Change:**

```nix
gtk = {
  enable = true;
  theme = { name = themeDark; package = colloid; };
  gtk4 = {
    theme = null;   # added — darkman script manages gtk-4.0 theme
  };
  iconTheme = { ... };
};
```

**Why `null`:** Home-manager's `gtk.gtk4` module writes
`~/.config/gtk-4.0/gtk.css` and related files. The theme.nix module already
disables those with `xdg.configFile."gtk-4.0/gtk.css".enable = mkForce false`
because the darkman switch script creates its own symlinks. Setting
`gtk.gtk4.theme = null` prevents home-manager from trying to manage the theme
while keeping cursor and icon settings intact.

### `xdg.userDirs.setSessionVariables` set to `false`

**File:** `hosts/yoga/home.nix`

The default changed from `true` to `false`. The legacy `true` value caused
home-manager to write XDG directory paths as session variables in shell
profile scripts. This is unnecessary because the theme switch script already
sets environment variables via `systemctl --user set-environment` and
`dbus-update-activation-environment`.

**Change:**

```nix
xdg.userDirs = {
  enable = true;
  createDirectories = true;
  setSessionVariables = false;   # added — new 26.05 default
  # ...
};
```

### `programs.firefox.configPath` set to XDG-compliant path

**File:** `home/browsers.nix`

The default changed from `".mozilla/firefox"` to
`"${config.xdg.configHome}/mozilla/firefox"`. Adopting the new path
(`~/.config/mozilla/firefox`) follows XDG Base Directory Specification.

**Change:**

```nix
programs.firefox = {
  enable = true;
  configPath = "${config.xdg.configHome}/mozilla/firefox";   # added
  # ...
};
```

**Manual migration required after deploying:**

```sh
# On each host with Firefox (yoga, latitude):
mkdir -p ~/.config/mozilla
mv ~/.mozilla/firefox ~/.config/mozilla/firefox
# Verify profile works, then:
rm -rf ~/.mozilla
```

On yoga (impermanence), the old path `~/.mozilla/firefox` is persisted but
`~/.config/mozilla/firefox` is not. Add the new path to the persistence list
in `hosts/yoga/home.nix`:

```nix
home.persistence."/persist".directories = [
  # ...
  { directory = ".config/mozilla/firefox"; mode = "0700"; }
  # ...
];
```

### Lix `or` identifier deprecation

```
warning: using or as an identifier is deprecated
```

Upstream Lix issue. `or` is a Nix keyword that is also used as an attrset
key in lix's own code. Harmless — does not affect this config.

## Hosts Evaluated Successfully

All three hosts produce valid derivations on NixOS 26.05:

```
yoga:       /nix/store/gv6z307qc7wdy5r6jlr2d5q6lxfcig39-nixos-system-yoga-26.05.20260608.bd0ff2d.drv
latitude:   /nix/store/lz0i9hppaylnnsk3dh5nv2f39iqj8cdw-nixos-system-latitude-26.05.20260608.bd0ff2d.drv
nix-media:  /nix/store/q98wiz9v82351lmbx9g9iiynzl8qicgc-nixos-system-nix-media-26.05.20260608.bd0ff2d.drv
```

## Deployment Notes

### First switch requires reboot

dbus-broker replaces the classic dbus-daemon as the default D-Bus
implementation. This change requires a full reboot — not just a service
restart. After `nixos-rebuild switch`, reboot immediately.

### Kernel module compatibility

GCC 14 → 15 may break out-of-tree kernel modules. The `ryzen-smu` module
(on yoga) is the primary risk. If the build fails, check:

```sh
nix log /nix/store/*-ryzen-smu-*/drv.log
```

### Impermanence

Hosts with impermanence (yoga) will have persistent directories wiped on
next boot. Add `.config/mozilla/firefox` to the persistence list before
deploying (see Firefox migration above). Other persistent directories are
unchanged.

### Firefox profile migration

After deploying, Firefox profiles must be moved from `~/.mozilla/firefox`
to `~/.config/mozilla/firefox`. See the `programs.firefox.configPath`
section above for commands. On yoga, also update the impermanence persistence
list.

## Files Changed

| File | Change |
|------|--------|
| `flake.nix` | Branch refs → 26.05, `nixfmt-rfc-style` → `nixfmt` |
| `flake.lock` | All inputs updated via `nix flake update` |
| `modules/core/networking.nix` | `extraConfig` → `settings` |
| `modules/core/users.nix` | Removed `programs.adb.enable`, added `pkgs.android-tools` |
| `modules/features/desktop-gnome.nix` | Removed `gdm.wayland = true` |
| `hosts/nix-media/monitoring.nix` | Added `secret_key` to Grafana security |
| `hosts/nix-media/default.nix` | `fastfetchMinimal` → `fastfetch.minimal` |
| `home/terminal.nix` | `fastfetchMinimal` → `fastfetch.minimal`, opencode `LD_LIBRARY_PATH` wrap |
| `home/theme.nix` | Added `gtk.gtk4.theme = null` |
| `home/browsers.nix` | Added `programs.firefox.configPath` (XDG path) |
| `hosts/yoga/home.nix` | Added `xdg.userDirs.setSessionVariables = false` |
| `hosts/nix-media/docker.nix` | Added `package = pkgs.docker_29` |

## Verification Commands

```sh
# Dry-eval all hosts (confirms no eval errors)
nix eval .#nixosConfigurations.yoga.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.latitude.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nix-media.config.system.build.toplevel.drvPath

# Dry-build yoga (confirms all packages resolve)
nix build .#nixosConfigurations.yoga.config.system.build.toplevel --dry-run

# After deploying, verify dbus-broker is running
systemctl status dbus-broker.service

# Check for leftover deprecation warnings
nix eval .#nixosConfigurations.yoga.config.system.build.toplevel.drvPath 2>&1 | grep warning
```
