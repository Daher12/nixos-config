# NixOS Config Optimizations — Before/After

Each change with diff, file location, and rationale.

---

## 1. `flake.nix` — Add `follows` for impermanence

**File:** `flake.nix:40`

```diff
-    impermanence.url = "github:nix-community/impermanence";
+    impermanence = {
+      url = "github:nix-community/impermanence";
+      inputs.nixpkgs.follows = "nixpkgs";
+    };
```

**Why:** Every other flake input follows your nixpkgs instance. Impermanence was the only one that didn't. Without `follows`, the impermanence flake pulls its own independent nixpkgs revision, potentially duplicating packages in the evaluation graph and increasing eval/closure size.

---

## 2. `modules/core/nix.nix` — Make `optimise.dates` configurable

**File:** `modules/core/nix.nix:32-36`

```diff
-    optimise.automatic = lib.mkOption {
-      type = lib.types.bool;
-      default = true;
-      description = "Automatically optimize Nix store";
-    };
+    optimise = {
+      automatic = lib.mkOption {
+        type = lib.types.bool;
+        default = true;
+        description = "Automatically optimize Nix store";
+      };
+      dates = lib.mkOption {
+        type = lib.types.listOf lib.types.str;
+        default = [ "weekly" ];
+        description = "When to run Nix store optimisation";
+      };
+    };
```

**Why:** `gc.dates` was already configurable but `optimise.dates` was hardcoded to `[ "weekly" ]`. This makes them consistent. The default is identical so there's no behavioral change; hosts can now override the schedule.

---

## 3. `modules/core/nix.nix` — Use `inherit` for optimise dates

**File:** `modules/core/nix.nix:107-111`

```diff
       optimise = lib.mkIf cfg.optimise.automatic {
         automatic = true;
-        dates = [ "weekly" ];
+        inherit (cfg.optimise) dates;
       };
```

**Why:** Follows from change #2. Reads the now-configurable option. Also satisfies the `statix` lint rule about matching attribute names.

---

## 4. `modules/core/nix.nix` — Remove unused `pkgs.cachix`

**File:** `modules/core/nix.nix:117-120`

```diff
     systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];
-
-    environment.systemPackages = [ pkgs.cachix ];
```

**Why:** `cachix` CLI is only needed if you push to Cachix caches. Your config only consumes from caches (pulls), never pushes. Removing it trims closure size and avoids pulling the entire Haskell ecosystem that `pkgs.cachix` depends on.

Also removed `pkgs` from the function arguments since it was the sole consumer:

```diff
 {
   config,
   lib,
-  pkgs,
   inputs,
   self,
   mainUser,
   ...
 }:
```

---

## 5. `modules/core/users.nix` — Drop redundant documentation sub-options

**File:** `modules/core/users.nix:144-150`

```diff
-    documentation = {
-      enable = false;
-      nixos.enable = false;
-      man.enable = false;
-      info.enable = false;
-      doc.enable = false;
-    };
+    documentation.enable = false;
```

**Why:** Setting `documentation.enable = false` already disables all five sub-modules transitively (nixos, man, info, doc). The explicit sub-disables were redundant. The behavior is identical.

---

## 6. `modules/features/onlyoffice.nix` — Standardize to `lib.` prefix

**File:** `modules/features/onlyoffice.nix:1-79` (entire file rewritten)

```diff
-let
-  inherit (lib)
-    mkDefault
-    mkEnableOption
-    mkIf
-    mkOption
-    optionals
-    types
-    ;
-  cfg = config.features.onlyoffice;
-in
+let
+  cfg = config.features.onlyoffice;
+in
 {
   options.features.onlyoffice = {
-    enable = mkEnableOption "ONLYOFFICE Desktop Editors";
-    package = mkOption { type = types.package; ... };
-    installCompatibilityFonts = mkOption { type = types.bool; ... };
-    enableSharedFonts = mkOption { type = types.bool; ... };
-    cursorSize = mkOption { type = types.int; ... };
-    setGlobalCursorSize = mkOption { type = types.bool; ... };
+    enable = lib.mkEnableOption "ONLYOFFICE Desktop Editors";
+    package = lib.mkOption { type = lib.types.package; ... };
+    installCompatibilityFonts = lib.mkOption { type = lib.types.bool; ... };
+    enableSharedFonts = lib.mkOption { type = lib.types.bool; ... };
+    cursorSize = lib.mkOption { type = lib.types.int; ... };
+    setGlobalCursorSize = lib.mkOption { type = lib.types.bool; ... };
   };
   config = lib.mkIf cfg.enable {
-    features.fonts.enable = mkIf cfg.enableSharedFonts (mkDefault true);
-    fonts.packages = optionals cfg.installCompatibilityFonts [ pkgs.liberation_ttf ];
-    environment.sessionVariables = mkIf cfg.setGlobalCursorSize { ... };
+    features.fonts.enable = lib.mkIf cfg.enableSharedFonts (lib.mkDefault true);
+    fonts.packages = lib.optionals cfg.installCompatibilityFonts [ pkgs.liberation_ttf ];
+    environment.sessionVariables = lib.mkIf cfg.setGlobalCursorSize { ... };
   };
 }
```

**Why:** Every other module in the codebase uses the `lib.mkDefault`, `lib.mkIf`, etc. qualified form. This one module used bare `mkDefault`/`mkIf` aliases via `inherit (lib)`, creating an inconsistency. The qualifed form is more explicit and easier to grep. No functional change.

---

## 7. `modules/features/desktop-gnome.nix` — Remove `openssl` from systemPackages

**File:** `modules/features/desktop-gnome.nix:121-124`

```diff
         gnomeExtensions.blur-my-shell
         gtk3
         papers
-        openssl
       ];
```

**Why:** `openssl` (the CLI utility) was in systemPackages. OpenSSL the library is pulled transitively by dozens of packages via `openssl.dev`/`openssl.out`. The CLI binary (`openssl` command) is rarely needed interactively on a desktop. If you do use the command-line OpenSSL tool, install it explicitly via home-manager packages instead.

---

## 8. `modules/features/filesystem.nix` — Add `balanceFilesystems` option

**File:** `modules/features/filesystem.nix:14-19,78-82,119`

```diff
+  resolvedBalanceFs =
+    if cfg.btrfs.balanceFilesystems != [ ] then
+      cfg.btrfs.balanceFilesystems
+    else
+      cfg.btrfs.scrubFilesystems;

 in
 ...
       autoBalance = lib.mkOption { ... };
+
+      balanceFilesystems = lib.mkOption {
+        type = lib.types.listOf lib.types.str;
+        default = [ ];
+        description = "Filesystems to balance (defaults to scrubFilesystems when empty)";
+      };
 ...
           ${lib.concatMapStringsSep "\n" (
             fs: "btrfs balance start -dusage=10 -musage=10 ${fs}"
-          ) cfg.btrfs.scrubFilesystems}
+          ) resolvedBalanceFs}
```

**Why:** The old code reused `scrubFilesystems` for both scrubbing AND balancing. These are different operations — scrubbing checks data integrity on ALL data, while balancing redistributes data allocation. You might want to scrub everything but only balance the root subvolume. The new `balanceFilesystems` option lets you specify different target filesystems. When empty (default), it falls back to `scrubFilesystems` for backward compatibility.

---

## 9. `hosts/yoga/home.nix` — Remove commented-out RDP flag alternatives

**File:** `hosts/yoga/home.nix:164-173`

```diff
     debug = true;
-
-    # Maximum responsiveness:
-    #rdpFlags = "/cert:tofu /usb:auto /clipboard +auto-reconnect /network:lan /audio-mode:1 /bpp:16 -gfx +relax-order-checks +async-update +async-channels /frame-ack:0 /size:2048x1240";
-
-    # Balanced:
     rdpFlags = "/cert:tofu /usb:auto /clipboard +auto-reconnect /network:lan /audio-mode:1 /gfx:RFX +async-update +async-channels /frame-ack:0 /size:2048x1240";
-
-    # Maximum fluidity:
-    #rdpFlags = "/cert:tofu /usb:auto /clipboard +auto-reconnect /network:lan /audio-mode:1 /gfx:AVC444 +async-update +async-channels /frame-ack:0 /size:2048x1240";
```

**Why:** Dead commented-out code. Three alternative RDP configurations were kept as comments ("Maximum responsiveness", "Balanced", "Maximum fluidity"). The active one is "Balanced". If you need to switch, re-set the `rdpFlags` option in this file — it's declarative, no comments needed.

---

## 10. `hosts/yoga/home.nix` — Use `config.home.homeDirectory`

**File:** `hosts/yoga/home.nix:4-7`

```diff
 {
+  config,
   lib,
   ...
 }:
 let
-  homeDir = "/home/dk";
+  homeDir = config.home.homeDirectory;
```

And:

```diff
-    sessionPath = [ "/home/dk/.local/bin" ];
+    sessionPath = [ "${homeDir}/.local/bin" ];
```

**Why:** Hardcoded `/home/dk` duplicates what home-manager already knows. `config.home.homeDirectory` is the canonical source. This prevents drift if the username or home path ever changes.

---

## 11. `hosts/latitude/default.nix` — Remove dead comment

**File:** `hosts/latitude/default.nix:37`

```diff
   ];
-
-  #  users.mutableUsers = lib.mkForce true;

   system.stateVersion = "25.05";
```

**Why:** Dead commented-out code with no value. Already configured via `modules/core/users.nix` with `mutableUsers = false`.

---

## Lix Cache — Analysis

**Checked:** `https://cache.lix.systems` is reachable and serving content (HTTP 200).

**Verdict: KEEP it.** You're tracking `lix/main.tar.gz` (bleeding-edge). Most commits won't have cache hits since the cache is built for releases, not every dev commit. However:

- Evaluation overhead is negligible (one extra substituter URL)
- When there IS a cache hit (on cached releases or popular revisions), it saves a full Lix source build (C++ / ~5-10 min)
- The Lix project recommends having it

No change needed here. If you switch to a tagged Lix release (e.g., `lix=2.93`), the cache will become significantly more effective.

---

## Summary

| # | File | Type | Impact |
|---|---|---|---|
| 1 | `flake.nix` | Eval perf | Reduces duplicate nixpkgs instances |
| 2-4 | `modules/core/nix.nix` | Config + dead code | Configurable option + reduced closure |
| 5 | `modules/core/users.nix` | Redundancy | Cleaner config, identical behavior |
| 6 | `modules/features/onlyoffice.nix` | Style | Consistency, no functional change |
| 7 | `modules/features/desktop-gnome.nix` | Closure size | Remove unnecessary CLI tool |
| 8 | `modules/features/filesystem.nix` | Feature | Separate balance/scrub targets, backward compat |
| 9 | `hosts/yoga/home.nix` | Dead code | Remove commented RDP alternatives |
| 10 | `hosts/yoga/home.nix` | DRY | Derive home dir from config |
| 11 | `hosts/latitude/default.nix` | Dead code | Remove commented line |
