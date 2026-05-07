# NixOS Config Optimizations — Round 2

Deep dive analysis and fixes for best practices, DRY, and clean code.

---

## 1. `home/default.nix` — Accept `homeDirectory` as argument

**File:** `home/default.nix:1-16`

**Priority:** 🔴 High — Inconsistency with recent optimizations

```diff
- { mainUser, ... }:
+ { homeDirectory ? "/home/${mainUser}", mainUser, ... }:

  {
    imports = [
      ./browsers.nix
      ./git.nix
      ./terminal.nix
      ./theme.nix
      ./winapps.nix
    ];

    programs.home-manager.enable = true;

    home = {
      username = mainUser;
-     homeDirectory = "/home/${mainUser}";
+     homeDirectory = homeDirectory;
```

**Why:** The recent optimization in `hosts/yoga/home.nix` correctly uses `config.home.homeDirectory` to derive the home directory dynamically. The shared `home/default.nix` module had a hardcoded path, creating an inconsistency. Now `homeDirectory` is passed via `specialArgs` from `mkHost.nix` (which computes it once), ensuring all home-manager modules use the same canonical source.

**Supporting change in `lib/mkHost.nix:26-37`:**
```diff
  commonArgs = {
    inherit
      inputs
      self
      flakeRoot
      mainUser
      ;
+   homeDirectory = "/home/${mainUser}";
    pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${system};
  }
```

This ensures `homeDirectory` is computed once in `mkHost.nix` and passed to all home-manager modules via `extraSpecialArgs`.

---

## 2. `modules/features/sops.nix` — Use `flakeRoot` for secrets path

**File:** `modules/features/sops.nix:1-13`

**Priority:** 🔴 High — Fragile relative path

```diff
  {
    config,
+   flakeRoot,
    lib,
    pkgs,
    inputs,
    ...
  }:

  let
    cfg = config.features.sops;
    hostname = config.networking.hostName;
-   secretsPath = ../../secrets/hosts/${hostname}.yaml;
+   secretsPath = "${flakeRoot}/secrets/hosts/${hostname}.yaml";
```

**Why:** The old code used a relative path `../../secrets/hosts/` which depends on the module file's location in the directory tree. If the module is ever moved or refactored, the path breaks silently. Using `flakeRoot` (passed via `specialArgs` in `mkHost.nix`) provides an absolute reference to the flake root, making the path robust and independent of module location.

---

## 3. `profiles/laptop.nix` — Make WiFi UUIDs configurable

**File:** `profiles/laptop.nix:1-61`

**Priority:** 🔴 High — Hardcoded UUIDs cause conflicts

```diff
  { lib, config, ... }:

  let
+   cfg = config.laptop;
+
    homeWifiContent = ''
      [connection]
      id=HomeWiFi
-     uuid=7a3b4c5d-1234-5678-9abc-def012345678
+     uuid=${cfg.homeWifiUuid}
      type=wifi
      ...
    '';

    workWifiContent = ''
      [connection]
      id=WorkWiFi
-     uuid=8b4c5d6e-2345-6789-0bcd-ef1234567890
+     uuid=${cfg.workWifiUuid}
      type=wifi
      ...
    '';
  in
  lib.mkMerge [
    {
+     options.laptop = {
+       homeWifiUuid = lib.mkOption {
+         type = lib.types.str;
+         default = "7a3b4c5d-1234-5678-9abc-def012345678";
+         description = "UUID for home WiFi NetworkManager connection";
+       };
+       workWifiUuid = lib.mkOption {
+         type = lib.types.str;
+         default = "8b4c5d6e-2345-6789-0bcd-ef1234567890";
+         description = "UUID for work WiFi NetworkManager connection";
+       };
+     };
+
      features = {
        bluetooth.enable = lib.mkDefault true;
        ...
```

**Why:** NetworkManager UUIDs must be unique across all connections. Hardcoding them in a profile that may be used by multiple hosts risks UUID collisions. Making them configurable options preserves the defaults while allowing per-host overrides. This follows the DRY principle and makes the profile reusable.

---

## 4. Multiple files — Replace `with pkgs;` with explicit `pkgs.` prefix

**Files:**
- `modules/features/desktop-gnome.nix:111-124`
- `modules/features/fonts.nix:21-30`
- `modules/hardware/amd-gpu.nix:23-27`
- `hosts/yoga/default.nix:167-170`
- `hosts/latitude/default.nix:125-128`
- `hosts/nix-media/default.nix:111-126`
- `home/terminal.nix:133-148`

**Priority:** 🟡 Medium — Best practice, statix linting

```diff
  # Before (desktop-gnome.nix):
    environment = {
      gnome.excludePackages = with pkgs; [
        gnome-photos
        gnome-tour
        ...
      ];
      systemPackages = with pkgs; [
        nautilus
        file-roller
        ...
      ];
    };

  # After:
    environment = {
      gnome.excludePackages = [
        pkgs.gnome-photos
        pkgs.gnome-tour
        ...
      ];
      systemPackages = [
        pkgs.nautilus
        pkgs.file-roller
        ...
      ];
    };
```

**Why:** Using `with pkgs;` brings ALL attributes of `pkgs` into scope, which:
1. **Hides variable origins** — harder to trace where a name comes from
2. **Can cause shadowing bugs** — if a local variable shares a name with a pkgs attribute
3. **Violates statix lint rules** — `statix` recommends against `with` usage
4. **Reduces grep-ability** — searching for `pkgs.foo` won't find `foo` inside a `with pkgs` block

The explicit `pkgs.` prefix is more verbose but clearer, safer, and passes lint checks. This is consistent with the recent change to `onlyoffice.nix` which standardized on `lib.` prefix.

---

## Summary

| # | File | Priority | Type | Impact |
|---|---|---|---|---|
| 1 | `home/default.nix` + `lib/mkHost.nix` | 🔴 High | Bug fix | Consistency with recent optimizations |
| 2 | `modules/features/sops.nix` | 🔴 High | Robustness | Path independent of module location |
| 3 | `profiles/laptop.nix` | 🔴 High | DRY/Reusability | Configurable UUIDs for multi-host use |
| 4 | 7 files | 🟡 Medium | Best practice | Explicit pkgs. refs, passes statix |

**Total changes:** 4 optimizations across 10 files

---

## Verification

Run the following to verify all changes:

```bash
# Check flake evaluation
nix flake check

# Run lint checks (defined in flake.nix)
nix build .#checks.x86_64-linux.statix
nix build .#checks.x86_64-linux.deadnix
nix build .#checks.x86_64-linux.nixfmt

# Test building a host
nix build .#nixosConfigurations.yoga.config.system.build.toplevel
```
