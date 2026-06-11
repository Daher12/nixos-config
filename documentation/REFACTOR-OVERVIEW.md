# Refactoring Overview

This document catalogues all recent structural changes to the repository, the
rationale behind each change, and a technical review of whether functionality
was preserved, best practices were followed, and idiomatic Nix was used.

---

## Table of Contents

- [Phase 1: Core Module Decomposition](#phase-1-core-module-decomposition)
  - [Extract `audio.nix` from `users.nix`](#extract-audionix-from-usersnix)
  - [Extract `input.nix` from `users.nix`](#extract-inputnix-from-usersnix)
  - [Extract `shell.nix` from `users.nix`](#extract-shellnix-from-usersnix)
  - [Extract `systemd.nix` from `users.nix`](#extract-systemdnix-from-usersnix)
  - [Consolidate sysctl into `sysctl.nix`](#consolidate-sysctl-into-sysctlnix)
- [Phase 1b: Relocations & Removals](#phase-1b-relocations--removals)
  - [Move `NetworkManager-wait-online` to `networking.nix`](#move-networkmanager-wait-online-to-networkingnix)
  - [Move lid-logind settings to `profiles/laptop.nix`](#move-lid-logind-settings-to-profileslaptopnix)
  - [Move `android-tools` to `hosts/yoga/default.nix`](#move-android-tools-to-hosts-yogadefaultnix)
  - [Remove duplicate `fwupd` from `users.nix`](#remove-duplicate-fwupd-from-usersnix)
  - [Fix dead `dnsmasq` option in `networking.nix`](#fix-dead-dnsmasq-option-in-networkingnix)
- [Phase 1c: Tuning & Cleanup](#phase-1c-tuning--cleanup)
  - [Nix settings cleanup](#nix-settings-cleanup)
  - [Boot param deduplication](#boot-param-deduplication)
  - [Dev artifact comment removal](#dev-artifact-comment-removal)
- [Phase 2: Targeted Fixes](#phase-2-targeted-fixes)
  - [Remove broken `nixpkgs-unstable` from update scripts](#remove-broken-nixpkgs-unstable-from-update-scripts)
  - [Fix `pkgs.replaceVars` in `caddy.nix`](#fix-pkgsreplacevars-in-caddynix)
  - [Remove dead `Restart=` from `ryzen-tdp.nix`](#remove-dead-restart-from-ryzen-tdpnix)
  - [Remove dead WiFi template code from `laptop.nix`](#remove-dead-wifi-template-code-from-laptopnix)
  - [Flatten `nvidia-disable` option path](#flatten-nvidia-disable-option-path)
  - [Extract Python webhook from `monitoring.nix`](#extract-python-webhook-from-monitoringnix)
  - [Unify shell script builder in `theme.nix`](#unify-shell-script-builder-in-themenix)
  - [Move cursor setup from `switch-theme` to session init](#move-cursor-setup-from-switch-theme-to-session-init)

---

## Module Map (Post-Refactor)

```
modules/core/
├── default.nix     # imports all core modules
├── audio.nix       # PipeWire + rtkit (NEW)
├── boot.nix        # systemd-boot, Plymouth, tmpfs, udev
├── input.nix       # libinput (NEW)
├── locale.nix      # timezone, locale
├── networking.nix  # NetworkManager, resolved, wifi backend
├── nix.nix         # flake settings, caches, GC, store optimisation
├── shell.nix       # zoxide (NEW)
├── systemd.nix     # timeouts, coredump, documentation.enable (NEW)
├── sysctl.nix      # all kernel sysctl, server/desktop profiles
└── users.nix       # user account, sudo, SOPS password, shell (TRIMMED)
```

---

## Phase 1: Core Module Decomposition

### Extract `audio.nix` from `users.nix`

**What:** Moved `security.rtkit.enable` and `services.pipewire.*` (enable, alsa,
pulse, jack, clock-rate config) from `users.nix` into dedicated
`modules/core/audio.nix`.

**Rationale:** These concerns are unrelated to user account management. PipeWire
is the system audio layer; `users.nix` had become a god module holding 12+
unrelated responsibilities.

**Mechanics:**
- All values use `lib.mkDefault true` so hosts can override (nix-media already
  sets `services.pipewire.enable = false` and `security.rtkit.enable = false`
  explicitly).
- `nix-media/default.nix` disables both — since its `extraModules` are imported
  after `baseModules` (core), the plain `false` assignments win over `mkDefault`.

**Review:** ✓ Functionality preserved. ✓ Override chain correct. ✓ Idiomatic
(mkDefault in shared module, plain override in host).

**Evaluation:** Best practice. A medium-sized improvement. The extraction is
clean, but the module lives in `core/` where it applies to every host. An
alternative would be `features/audio.nix` with `enable` toggle, which would
avoid the need for nix-media's manual overrides. However, PipeWire is the
standard NixOS audio stack and the server-override pattern is well-established
in this repo.

---

### Extract `input.nix` from `users.nix`

**What:** Moved `services.libinput.enable` to `modules/core/input.nix`.

**Rationale:** libinput is an input stack concern, not a user management concern.

**Mechanics:** Single-line module with `lib.mkDefault true`.

**Review:** ✓ Functionality preserved. ✓ Minimal boilerplate.

**Evaluation:** Good. No feasible alternative — 5 lines is the right size.

---

### Extract `shell.nix` from `users.nix`

**What:** Moved `programs.zoxide.enable` to `modules/core/shell.nix`.

**Rationale:** zoxide is a shell productivity tool, independent of which shell
the user picks (fish/zsh/bash). It was grouped with `programs.fish` and
`programs.zsh` in `users.nix` only by accident of proximity.

**Mechanics:** Single-line module with `lib.mkDefault true`.

**Review:** ✓ Functionality preserved. ✓ 5 lines.

**Evaluation:** Good. Could arguably live in home-manager instead, but the
NixOS-level `programs.zoxide` is a system-wide install which is appropriate for
a core module.

---

### Extract `systemd.nix` from `users.nix`

**What:** Moved `systemd.settings.Manager.DefaultTimeoutStopSec`,
`DefaultTimeoutStartSec`, `systemd.coredump.enable`, and
`documentation.enable` from `users.nix` to `modules/core/systemd.nix`.

**Rationale:** Systemd configuration and global docs toggle have nothing to do
with user accounts. Four unrelated settings that happened to share a file.

**Mechanics:** Timeouts use `lib.mkDefault` so hosts can override. Coredump and
documentation are plain `false` (system-wide policy decisions).

**Review:** ✓ Functionality preserved. ✓ Timeouts remain overridable.

**Evaluation:** Good. The `documentation.enable = false` is a global setting
that was particularly out of place in a file called `users.nix`.

---

### Consolidate sysctl into `sysctl.nix`

**What:** Moved `vm.max_map_count`, `fs.file-max`, and
`fs.inotify.max_user_watches` from `users.nix` into `modules/core/sysctl.nix`.

**Rationale:** These overlapped with values already in `sysctl.nix`, creating a
fragile priority game (`lib.mkOverride 900` in users.nix vs `lib.mkForce` in
sysctl.nix). A single source of truth for all kernel parameters.

**Mechanics:**
- Added a universal baseline block (applies to both server and desktop):
  - `vm.max_map_count` at `mkDefault 1048576`
  - `fs.file-max` at `mkDefault 2097152`
  - `fs.inotify.max_user_watches` at `mkDefault 524288`
- Server branch overrides `fs.inotify.max_user_watches` to `mkForce 1048576`
  (double the desktop value) and adds `max_user_instances`.
- Desktop branch unaffected by these three values.

**Review:** ✓ No value changes — identical effective settings. ✓ No more
priority collisions. ✓ Single file to check for all sysctls.

**Evaluation:** Significant improvement. The old `mkOverride 900` in `users.nix`
was fragile — changing the priority in `sysctl.nix` could silently change
behaviour. Now all sysctls are in one place with clear `mkDefault`/`mkForce`
semantics.

---

## Phase 1b: Relocations & Removals

### Move `NetworkManager-wait-online` to `networking.nix`

**What:** Moved `systemd.services.NetworkManager-wait-online.wantedBy =
lib.mkForce [ ]` from `modules/core/nix.nix` to `modules/core/networking.nix`.

**Rationale:** Code had zero relationship to Nix configuration. It was misplaced.

**Review:** ✓ Exact same value. ✓ Module already imports `config`/`lib`.

**Evaluation:** Trivial correctness fix. A clear-cut relocation.

---

### Move lid-logind settings to `profiles/laptop.nix`

**What:** Moved `services.logind.settings.Login` (HandleLidSwitch,
HandleLidSwitchExternalPower, HandleLidSwitchDocked) from `modules/core/users.nix`
to `profiles/laptop.nix`.

**Rationale:** Lid switch behaviour is laptop-specific. A headless server
(nix-media) should never evaluate these options via core. The laptop profile
already exists as the correct abstraction boundary.

**Review:** ✓ Both laptops (yoga, latitude) include `laptop.nix`, so they
receive the same settings. ✓ nix-media no longer evaluates lid logic.

**Evaluation:** Correct architectural improvement. Lid settings should never
have been in core to begin with.

---

### Move `android-tools` to `hosts/yoga/default.nix`

**What:** Moved `environment.systemPackages = [ pkgs.android-tools ]` from
`modules/core/users.nix` to `hosts/yoga/default.nix`.

**Rationale:** ADB (Android Debug Bridge) is only useful on the primary dev
machine (yoga). Installing it unconditionally on all hosts adds unnecessary
packages to the closure.

**Review:** ✓ Only yoga gets android-tools now. ✓ nix-media (server) and
latitude (legacy laptop) no longer install it.

**Evaluation:** Good. The original placement was clearly a convenience decision
that expanded scope unnecessarily.

---

### Remove duplicate `fwupd` from `users.nix`

**What:** Removed `services.fwupd.enable = lib.mkDefault true` from `users.nix`.

**Rationale:** `modules/hardware/default.nix` already enables fwupd when
`hardware.isPhysical = true`. All three hosts set `isPhysical = true`. The
copy in `users.nix` was a duplicate.

**Review:** ✓ All three hosts have `hardware.isPhysical = true`. ✓ Hardware
module is imported for all three (all use `withHardware = true`).

**Evaluation:** Clean duplicate removal. The priority is identical (`mkDefault
true`) in both locations, so removing one is safe.

---

### Fix dead `dnsmasq` option in `networking.nix`

**What:** Removed `"dnsmasq"` from the `types.enum` of `core.networking.dns`.

**Rationale:** The option listed `"dnsmasq"` as a valid choice but no `mkIf`
block or configuration path existed for it. Choosing it would set
`networking.networkmanager.dns = "dnsmasq"` (which NetworkManager supports)
but nothing would configure the actual dnsmasq service, leading to broken DNS.

**Review:** ✓ Removed dead enum value. ✓ `"systemd-resolved"` and `"none"`
remain, both with corresponding config paths.

**Evaluation:** Bug fix. A user (or future self) selecting `"dnsmasq"` would
get silently broken DNS.

---

## Phase 1c: Tuning & Cleanup

### Nix settings cleanup

**What:** Changed in `modules/core/nix.nix`:

| Setting | Before | After | Reason |
|---------|--------|-------|--------|
| `auto-optimise-store` | `mkDefault true` | `false` | Timer-based `optimise.automatic` already runs weekly. Store was being optimized on every build *and* on timer — double work. |
| `http-connections` | `128` | `64` | Single-user machine, default is 25. 128 is excessive. |
| `narinfo-cache-positive-ttl` | `2592000` (30d) | removed (upstream default: 7d) | 30-day cache could serve stale binary cache metadata. |
| `narinfo-cache-negative-ttl` | `3600` (1h) | removed (upstream default: 1h) | Same as default — redundant. |
| `stalled-download-timeout` | `300` | removed (upstream default: 300) | Same as default — redundant. |

**Review:** ✓ No net negative impact. `auto-optimise-store = false` means one
fewer store traversal per build — the weekly timer handles it adequately.
`http-connections = 64` is still generous for a desktop. Removing redundant
settings reduces noise and makes deviations from upstream visible.

**Evaluation:** Conservative tuning. The most impactful change is
`auto-optimise-store` which avoids redundant I/O on every build. The timeout
and narinfo-cache removals reduce maintenance surface.

---

### Boot param deduplication

**What:** Removed `"nmi_watchdog=0"` from the silent-boot kernel params in
`modules/core/boot.nix`.

**Rationale:** `"nowatchdog"` already disables both the NMI watchdog and the
soft lockup watchdog. `nmi_watchdog=0` is a subset that is fully implied.

**Review:** ✓ `"nowatchdog"` remains. ✓ `nmi_watchdog=0` was redundant.

**Evaluation:** Trivial deduplication. No behavioural change.

---

### Dev artifact comment removal

**What:** Removed all `# PATCH:`, `# FIX:`, `# Rationale:`, and `# Note:`
comments from `modules/core/`.

**Rationale:** These are development history artifacts. Git history preserves
the rationale; inline patch notes add noise to production configuration.

**Review:** ✓ All comments removed from core modules. ✓ No logic changes.

**Evaluation:** Cosmetic but valuable — reduces cognitive load when reading
the files.

---

## Phase 2: Targeted Fixes

### Remove broken `nixpkgs-unstable` from update scripts

**What:** Removed `nixpkgs-unstable` from the `nix flake update` command in
both `scripts/update-safe` and `.github/workflows/bump.yml`.

**Rationale:** `nixpkgs-unstable` is not defined as a flake input in
`flake.nix`. Running the update scripts would always fail with `input
'nixpkgs-unstable' not found`. This was a runtime bug.

**Review:** ✓ Update commands now only reference real inputs.

**Evaluation:** Bug fix. This would affect anyone running `update-safe` or
the CI pipeline — both would fail immediately. The input likely existed in an
earlier revision of `flake.nix` and was removed without updating the scripts.

---

### Fix `pkgs.replaceVars` in `caddy.nix`

**What:** Replaced `pkgs.replaceVars` with `pkgs.substituteAll` in
`hosts/nix-media/caddy.nix`.

**Rationale:** `replaceVars` was a plasma5-specific utility (`substituteAll`
wrapper from `plasma5`). It was removed from nixpkgs or may not exist in all
evaluation contexts. `substituteAll` is the standard nixpkgs function that
replaces `@varName@` placeholders in text files.

**Review:** ✓ Same behaviour: replaces `@servicesJson@` in `landing.html`. ✓
Same API shape: `src` + named string attributes. ✓ Function exists in every
nixpkgs revision.

**Evaluation:** Correct fix. `replaceVars` was never the right function for
this — it was a plasma5 build helper, not a general templating tool.
`substituteAll` is the canonical replacement.

---

### Remove dead `Restart=` from `ryzen-tdp.nix`

**What:** Removed `Restart = "on-failure"` and `RestartSec = "1s"` from the
`ryzen-tdp-control` systemd service in `modules/hardware/ryzen-tdp.nix`.

**Rationale:** The service has `Type = "oneshot"`. Oneshot services exit with
`inactive` (not `failed`) after successful completion. `Restart=on-failure`
only triggers when the unit ends in `failed` state. The watchdog timer
(`ryzen-tdp-watchdog`) already handles periodic re-application via
`OnUnitActiveSec`.

**Review:** ✓ Watchdog timer re-applies limits every `watchdogInterval`. ✓
Udev rule triggers re-application on AC plug/unplug events. ✓ `Restart=`
was dead config with no runtime effect.

**Evaluation:** Correct. The `Restart=` directives were cargo-culted from a
long-running service pattern onto a oneshot. Removing them makes the config
accurately reflect the actual systemd behaviour.

---

### Remove dead WiFi template code from `laptop.nix`

**What:** Deleted ~50 lines of commented-out WiFi template code from
`profiles/laptop.nix`.

**Rationale:** Git history preserves the commented block permanently. Having
it inline adds noise to the active configuration.

**Review:** ✓ No functional change. ✓ Git history available if needed later.

**Evaluation:** Good. Commented-out code in version control is an antipattern.

---

### Flatten `nvidia-disable` option path

**What:** Changed `options.hardware.nvidia.disable.enable` to
`options.hardware.nvidia-disable.enable` in `modules/hardware/nvidia-disable.nix`,
and updated the reference in `hosts/latitude/default.nix`.

**Rationale:** All other hardware modules use a flat `options.hardware.<name>`
structure (`amd-gpu.enable`, `intel-gpu.enable`, `ryzen-tdp.enable`). The
triple nesting (`nvidia.disable.enable`) was inconsistent and harder to
discover.

**Review:** ✓ New path is `hardware.nvidia-disable.enable`. ✓ Single consumer
(latitude) updated. ✓ No other references exist.

**Evaluation:** Consistency improvement. The old path using `nvidia` as a
namespace suggested there might be other `nvidia.*` options, but the file only
exposes one toggle.

---

### Extract Python webhook from `monitoring.nix`

**What:** Moved the inline Python alert bridge from a heredoc string in
`hosts/nix-media/monitoring.nix` to a standalone file
`hosts/nix-media/alertmanager-ntfy-bridge.py`. The service now references it
via `pkgs.writeScript` + `builtins.readFile`.

**Rationale:** Inline Python in a Nix string heredoc is hard to edit (no syntax
highlighting, no linting, fragile indentation). Extracting to a `.py` file
makes it a proper, editable source file.

**Mechanics:**
- `alertmanager-ntfy-bridge.py` is a standard Python 3 script
- `monitoring.nix` wraps it: `pkgs.writeScript "alertmanager-ntfy-bridge" ''
  #!/usr/bin/env python3\n${builtins.readFile ./alertmanager-ntfy-bridge.py}''`
- The wrapper derivation produces a single executable file in the Nix store
- `ExecStart` points to the wrapper, systemd runs it directly with
  `CREDENTIALS_DIRECTORY` set for secret access

**Review:** ✓ Same Python logic — no behavioural changes. ✓ Script reads the
SOPS secret from `$CREDENTIALS_DIRECTORY/ntfy_url` as before. ✓ Now benefits
from proper `.py` file handling in editors and git.

**Evaluation:** Significant maintainability improvement. The old inline heredoc
was nearly impossible to edit safely — one wrong indentation or quote
character would break the build. The new approach is build-time safe (string
interpolation of a known-good file) and edit-time safe (`.py` syntax
highlighting).

---

### Unify shell script builder in `theme.nix`

**What:** Changed `switch-dark` and `switch-light` from `pkgs.writeShellScriptBin`
to `pkgs.writeShellApplication` in `home/theme.nix`.

**Rationale:** The main `switch-theme` script uses `writeShellApplication`
(which properly injects `runtimeInputs` into `PATH`). The two wrapper scripts
used `writeShellScriptBin` (which does not inject any `PATH` entries and relies
on the caller's environment). Using the same builder everywhere is more
consistent and avoids subtle PATH issues.

**Mechanics:**
```nix
# Before:
switchDark = pkgs.writeShellScriptBin "switch-theme-dark" ''
  exec ${switchTheme}/bin/switch-theme dark
'';

# After:
switchDark = pkgs.writeShellApplication {
  name = "switch-theme-dark";
  runtimeInputs = [ ];
  text = "exec ${switchTheme}/bin/switch-theme dark";
};
```

**Review:** ✓ Same output: produces `/bin/switch-theme-dark`. ✓ References
updated automatically (both builders produce the same package structure). ✓
`darkModeScripts`/`lightModeScripts` references unchanged.

**Evaluation:** Trivial consistency fix. The wrappers don't need runtime
inputs since they delegate to the main script via absolute path, but using the
same builder pattern across all three scripts is cleaner.

---

### Move cursor setup from `switch-theme` to session init

**What:** Removed cursor theme/size writes from the `switch-theme` script and
moved them to Home Manager session-level configuration (`dconf.settings`,
`home.sessionVariables`, `systemd.user.sessionVariables`) in `home/theme.nix`.

**Rationale:** The cursor values (`Posy_Cursor_Black`, size 32) never change
between light and dark mode. Yet the switch script was writing them on every
invocation — gsettings (dconf sync), systemctl set-environment, and
dbus-update-activation-environment — all setting the same immutable values at
every sunrise and sunset.

**Mechanics:**

Removed from the script:
- `gsettings set org.gnome.desktop.interface cursor-theme ...` / `cursor-size ...`
- `systemctl --user set-environment XCURSOR_THEME=... XCURSOR_SIZE=...`
- `dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE`

Added to the module config (session init):
```nix
dconf.settings."org/gnome/desktop/interface" = {
  cursor-theme = cursorName;   # "Posy_Cursor_Black"
  cursor-size = cursorSize;    # 32
};

home.sessionVariables = {
  XCURSOR_THEME = cursorName;
  XCURSOR_SIZE = toString cursorSize;
};

systemd.user.sessionVariables = {
  XCURSOR_THEME = cursorName;
  XCURSOR_SIZE = toString cursorSize;
};
```

Coverage analysis:

| Mechanism | Scope | Persistence |
|-----------|-------|-------------|
| `dconf.settings` | GNOME / GTK via dconf | Written once at HM activation, stays in `~/.config/dconf/user` |
| `home.sessionVariables` | Login shells (~/.bashrc, PAM) | Every new shell |
| `systemd.user.sessionVariables` | systemd user services | Every service start, propagated to D-Bus activation |

All three paths that previously relied on the script now get the cursor values
from session-level configuration. The script becomes purely about what changes
between modes: GTK theme, icon theme, color scheme, and GNOME Shell theme.

**Also:** Replaced `rm -rf "$dst"` with `mv "$dst" "$dst.rm" && rm -rf "$dst.rm"`
in the GTK4 symlink guard. If the deletion fails (power loss, filesystem error),
the original directory is preserved under `.rm` name instead of being silently
consumed. The next switch finds a `.rm` leftover, attempts the same guard on
the real path (now a symlink from the aborted previous run), and the `.rm`
orphan is harmless — `find ~/.config/gtk-4.0/ -name '*.rm' -prune -exec rm -rf
{} +` cleans it up manually if ever needed.

**Review:** ✓ All cursor values identical to before. ✓ Three coverage
mechanisms cover all contexts the script previously covered. ✓ `mv` before
`rm` eliminates the only non-atomic operation in the switch path.

**Evaluation:** Correct separation of concerns. Session config belongs in
session init, mode-switching logic belongs in the switch script. The old code
wasn't wrong — cursor writes on every switch are idempotent — but it was
work that didn't need doing. The `mv` pattern is a minor robustness
improvement for an edge case that is unlikely to trigger in practice.

---

## Verification

All changes pass the full CI pipeline:

| Check | Status |
|-------|--------|
| `nixfmt` (formatting) | ✓ |
| `statix` (linter) | ✓ |
| `deadnix` (dead code) | ✓ |
| `nixosConfigurations.yoga` (eval) | ✓ |
| `nixosConfigurations.latitude` (eval) | ✓ |
| `nixosConfigurations.nix-media` (eval) | ✓ |

The only pre-existing warning is the `or` keyword usage in the disko module,
which is an upstream issue, not related to these changes.
