# Msty Studio (AppImage)

Msty Studio is a closed-source Electron AI workspace app. It is **not in
nixpkgs**. The only Linux distribution format is an AppImage
(~1.8 GB), which requires special handling on NixOS.

## Files involved

| File | Purpose |
|------|---------|
| `pkgs/msty.nix` | Package derivation — fetches the AppImage, extracts it, wraps it in an FHS env with `appimageTools.wrapType2`, adds `--no-sandbox`, installs a `.desktop` entry |
| `hosts/yoga/home.nix` | Adds `msty` to `home.packages` and declares persistence directories |
| `pkgs/msty.md` | This documentation |

## Add msty to a host

1. **Import the package** in the host's `home.nix`:

   ```nix
   { config, lib, pkgs, flakeRoot, ... }:
   let
     msty = pkgs.callPackage (flakeRoot + "/pkgs/msty.nix") { };
   in
   {
     home.packages = [ msty ];
     # ...
   }
   ```

   `flakeRoot` is already available — it is passed via `extraSpecialArgs`
   in `lib/mkHost.nix`.

2. **Add persistence directories** (needed for impermanence — skip if the
   host does not use it):

   ```nix
   home.persistence."/persist".directories = [
     { directory = ".config/msty"; mode = "0700"; }
     { directory = ".local/share/msty"; mode = "0700"; }
   ];
   ```

3. **Build / deploy** as usual (`nus` / `update-safe`).

## Remove msty from a host

The goal is a fully residue-free removal: no Nix store copy, no user
data, no stale `.desktop`/icon entries, no leftover flake references.

1. **Edit the host's `home.nix`:**
   1. Remove `msty` from `home.packages` (line 76 in `hosts/yoga/home.nix`).
   2. Remove the `msty = pkgs.callPackage (flakeRoot + "/pkgs/msty.nix") { };`
      binding from the `let` block (line 10).
   3. If `pkgs` and `flakeRoot` are no longer used anywhere else in the
      file, remove them from the function argument list (lines 4-5). In
      `hosts/yoga/home.nix` they are only used for the msty binding, so
      both can be dropped.
   4. Remove the `.config/msty` and `.local/share/msty` entries from
      `home.persistence."/persist".directories` (lines 136-143).

2. **Verify no other host imports the package:**

   ```sh
   grep -r "msty" --include="*.nix"
   ```

   If only the host you are cleaning references `pkgs/msty.nix`, proceed
   to step 3. If another host still uses it, stop here — only remove
   the host-side wiring for the current host.

3. **Delete the package files:**

   ```sh
   rm pkgs/msty.nix pkgs/msty.md
   ```

4. **Rebuild and garbage-collect the store:**

   ```sh
   nus              # or: update-safe
   sudo nix-collect-garbage -d
   ```

   This drops `/nix/store/2hb30sgps6x9q65sr3pcvrn92vs1wall-msty-2.8.2/`
   and the cached 1.8 GB AppImage at
   `/nix/store/j3d56ikypvc37nbss9jsg84gkn7s8dbl-Msty_x86_64_amd64.AppImage`.

5. **Wipe user data:**
   - On impermanence-enabled hosts, the next boot erases
     `~/.config/msty` and `~/.local/share/msty` automatically.
   - Otherwise, remove them manually. Also remove `~/.cache/msty`
     (Electron cache, not covered by the persistence list):

     ```sh
     rm -rf ~/.config/msty ~/.local/share/msty ~/.cache/msty
     ```

6. **Refresh desktop and icon caches** so the removed `msty.desktop`
   and icon entries do not linger in application menus:

   ```sh
   update-desktop-database ~/.local/share/applications
   gtk-update-icon-cache -f ~/.local/share/icons/hicolor
   ```

   If neither command is on `$PATH`, the equivalent
   `nix-shell -p desktop-file-utils gnome.iconcache` provides them.

After step 6, the host has no msty residue in the Nix store, in user
data, in the persistence manifest, in `home.packages`, or in the
desktop environment.

## Why this approach

### `appimageTools.wrapType2` + `fetchurl` (chosen)

This is the idiomatic NixOS way to package an AppImage:

- **Fully declarative** — the AppImage URL and hash live in version
  control. Builds are reproducible.
- **Cached permanently** — `fetchurl` stores the 1.8 GB file in
  `/nix/store/` once, content-addressed by its SHA-256 hash. Subsequent
  builds and rebuilds reuse the cached copy; the file is never
  re-downloaded unless the URL or hash changes. Confirmed:
  `/nix/store/j3d56ikypvc37nbss9jsg84gkn7s8dbl-Msty_x86_64_amd64.AppImage`
  is the single cached copy used by every build.
- **FHS user environment** — `wrapType2` builds a minimal FHS tree
  (bubblewrap-based) so the Electron binary finds its expected Linux
  paths (`/lib64`, `/usr/lib`, …). Without this, ELF lookups fail on
  NixOS's non-FHS layout.
- **Desktop integration** — the derivation extracts the original
  `msty.desktop` from the AppImage, substitutes `Exec=AppRun` →
  `Exec=msty`, and copies the icons.

### Implementation notes

- **`nativeBuildInputs = [ makeWrapper ];`** is required. The
  `extraInstallCommands` script runs in a `runCommandLocal` environment;
  `makeWrapper` must be in `$PATH` for `wrapProgram` to be available.
  Without this, the build fails with `makeWrapper: command not found`.

- **`wrapProgram` instead of manual wrapper script.** `wrapType2` creates
  `$out/bin/msty` as a symlink to a generated bwrap script. `wrapProgram`
  rewrites this symlink into a real wrapper script that prepends
  `--no-sandbox` to the args. A manual `mv` + `cat` wrapper would also
  work, but `wrapProgram` is the nixpkgs standard.

- **`appimageContents` for the desktop file.** The `extraInstallCommands`
  reads `${appimageContents}/msty.desktop` (the real file extracted from
  the AppImage) and installs it. Writing the desktop file by hand would
  duplicate work and risk drift from upstream.

- **pname is `msty`, not `msty-studio`.** The binary and `.desktop` file
  inside the AppImage are named `msty`. Using the wrong name causes
  `install: cannot stat ...` errors.

- **`--no-sandbox`.** Electron's Chromium sandbox uses kernel features
  (namespaces, seccomp) that require either root or SUID helper binaries.
  Inside the NixOS FHS wrapper there is no SUID chrome-sandbox, so
  `--no-sandbox` is passed to disable the sandbox. This is standard
  practice for Electron apps on NixOS (see VS Code, Discord, Slack
  packages in nixpkgs).

- **`libsecret` and `libxcb` in `extraPkgs`.** `libsecret` is needed for
  the system keyring (API key storage). `libxcb` covers X11 client
  libraries sometimes needed by Electron for GPU/webview fallback paths
  on Wayland sessions.

### Why alternatives don't work

| Approach | Problem |
|----------|---------|
| **nixpkgs `msty` package** | Does not exist. Msty is closed-source and not packaged by nixpkgs. |
| **Manual AppImage download** | Not declarative — the file lives outside the Nix store, is lost on rebuild, and cannot be garbage-collected. |
| **`programs.appimage.binfmt`** | Enables running arbitrary AppImages via binfmt_misc, but still requires a manual download. Not declarative, not reproducible. |
| **`appimage-run`** | An older wrapper that unpacks AppImages at runtime. Deprecated in favour of `appimageTools`. Still requires you to place the AppImage file yourself. |
| **Flatpak / Snap** | Msty does not publish Flatpak or Snap packages. Even if it did, mixing package managers defeats the purpose of a declarative NixOS config. |
| **Building from source** | Msty is closed-source; no source is available. |
| **Deb extraction** | Msty publishes `.deb` files, but extracting one requires patching ELF binaries for NixOS's non-FHS layout. `appimageTools` already does this correctly. |

## Updating the AppImage

When Msty releases a new version:

1. Check the download page for the latest URL.
2. Update `version` in `pkgs/msty.nix`.
3. Replace the `hash` with a fake value (e.g. `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`).
4. Run `nix build` — Nix will error with the correct hash.
5. Paste the correct hash back into `pkgs/msty.nix`.
6. Rebuild and deploy.

## Changelog

### 2026-06-01 — Initial integration (yoga only)

Added Msty Studio support to the `yoga` host via AppImage wrapper.

**New files**

- `pkgs/msty.nix` — package derivation
- `pkgs/msty.md` — this documentation

**Modified files**

- `hosts/yoga/home.nix`

**Changes to `hosts/yoga/home.nix`**

1. Added `pkgs` and `flakeRoot` to the function arguments list (line 4-5).
2. Added `msty = pkgs.callPackage (flakeRoot + "/pkgs/msty.nix") { };`
   in the `let` block (line 9). `flakeRoot` is already passed via
   `extraSpecialArgs` in `lib/mkHost.nix`, so no flake-level change was
   needed.
3. Added `packages = [ msty ];` to `home` (line 76) to make the
   `msty` binary available in the user's `PATH`.
4. Added two persistence directories for impermanence (lines 136-141):
   - `.config/msty` (mode `0700`)
   - `.local/share/msty` (mode `0700`)

**Changes to `pkgs/msty.nix` (new file, 47 lines)**

- **`fetchurl`** downloads the AppImage from
  `https://assets.msty.app/prod/latest/linux/amd64/Msty_x86_64_amd64.AppImage`
  with pinned SHA-256 hash. The 1.8 GB file is stored once in
  `/nix/store/j3d56ikypvc37nbss9jsg84gkn7s8dbl-Msty_x86_64_amd64.AppImage`
  and reused for every build.
- **`appimageTools.extract`** pre-extracts the AppImage to a separate
  store path so the desktop file and icons can be copied out in
  `extraInstallCommands` without re-extracting at install time.
- **`appimageTools.wrapType2`** creates an FHS bubblewrap environment
  with all required libraries, then symlinks `$out/bin/msty` to a
  bwrap script.
- **`nativeBuildInputs = [ makeWrapper ]`** puts `wrapProgram` in `$PATH`
  during the install phase. Without this, the build fails with
  `makeWrapper: command not found` (this was the first build error
  encountered and fixed).
- **`extraPkgs`** adds `libsecret` (system keyring) and `xorg.libxcb`
  (X11 client libs) to the FHS env. The default `wrapType2` env
  already provides `gtk3`, `bashInteractive`, `zenity`, `xorg.xrandr`,
  `which`, `perl`, `xdg-user-dirs`, etc.
- **`extraInstallCommands`** does three things:
  1. `wrapProgram $out/bin/msty --add-flags "--no-sandbox"` — rewrites
     the symlink into a wrapper script that prepends `--no-sandbox`
     (required for Electron on NixOS; there is no SUID chrome-sandbox
     in the FHS env).
  2. Installs the upstream `msty.desktop` from the extracted AppImage,
   then `substituteInPlace --replace-fail` rewrites `Exec=AppRun` → `Exec=msty` so
   the launcher works.
  3. Copies the icons from the extracted AppImage to
     `$out/share/icons`.
- **`meta`** declares license as `unfree`, source provenance as
  `binaryNativeCode`, and `mainProgram = "msty"`.

**Bugs found and fixed during integration**

| Iteration | Problem | Fix |
|-----------|---------|-----|
| 1 | `makeWrapper: command not found` | Added `nativeBuildInputs = [ makeWrapper ];` |
| 2 | `install: cannot stat .../msty-studio.desktop` | Changed `pname` from `msty-studio` to `msty` (the actual filename inside the AppImage) |
| 3 | Hash mismatch | Used `nix-prefetch-url` to get the real SHA-256 of the AppImage, then updated to SRI format |

**Verification**

- `nix eval '.#nixosConfigurations.yoga.config.home-manager.users.dk.home.packages'`
  succeeds and includes `msty-2.8.2`.
- `nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home.path`
  produces a home-manager path with 706 symlinks; the msty derivation
  is in `/nix/store/2hb30sgps6x9q65sr3pcvrn92vs1wall-msty-2.8.2/`.
- `nix flake check` passes for all three hosts (yoga, latitude, nix-media).
- Output `$out/bin/msty` is a bash wrapper that exec's
  `msty-wrapped --no-sandbox "$@"`.
- Output `$out/share/applications/msty.desktop` has
  `Exec=msty --no-sandbox %U`.

**Caching confirmation**

The 1.8 GB AppImage is stored at
`/nix/store/j3d56ikypvc37nbss9jsg84gkn7s8dbl-Msty_x86_64_amd64.AppImage`
(read-only, 1825701123 bytes, content-addressed by hash). It is
fetched exactly once on the first build; every subsequent build
(including the one verified above) reuses the cached copy. The hash
in `pkgs/msty.nix` is a Nix integrity check — if the upstream file
changes, the build will refuse to use the cached copy and re-download.
