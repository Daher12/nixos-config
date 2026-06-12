# OpenCode Packaging on NixOS

Status: `✓` — Current and accurate.

---

## Overview

OpenCode is a Bun-compiled TUI application. Packaging it on NixOS requires
special handling because:

1. Bun binaries are dynamically linked and need interpreter patching
2. NixOS build hooks (`autoPatchelfHook`, `strip`) corrupt Bun's embedded payload
3. The `libstdc++.so.6` dependency requires an `LD_LIBRARY_PATH` wrapper

---

## Working Setup (Current)

**Source**: nixpkgs (`pkgs.opencode`) — builds from source using Bun.

**Version**: whatever nixpkgs ships (currently v1.15.10).

**Wrapper**: `LD_LIBRARY_PATH` for `libstdc++.so.6` (Bun file watcher fix).

```nix
programs.opencode = {
  enable = true;
  package = pkgs.opencode.overrideAttrs (previousAttrs: {
    postFixup = (previousAttrs.postFixup or "") + ''
      wrapProgram $out/bin/opencode \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  });
};
```

**Why this works**: nixpkgs builds opencode from source via Bun, producing a
properly wrapped binary. The `overrideAttrs` adds the `LD_LIBRARY_PATH` fix
for the Bun file watcher issue ([opencode #462](https://github.com/anomalyco/opencode/issues/462)).

---

## Why Pre-Built Binaries Don't Work

The GitHub release assets (`opencode-linux-x64.tar.gz`) contain Bun-compiled
binaries. These fail on NixOS due to three issues:

### 1. `autoPatchelfHook` corrupts Bun's binary format

Bun's `--compile` output embeds the entire JS runtime + application inside the
ELF binary using a custom section layout. `autoPatchelfHook` blindly rewrites
RPATH/interpreter entries in ways that break that internal structure.

Symptom: running `opencode` shows Bun's help text instead of the TUI.

### 2. `strip` corrupts the embedded Bun payload

NixOS's default `fixupPhase` strips binaries. For Bun-compiled executables,
this removes embedded data that the runtime needs.

Fix: `dontStrip = true;` — but this alone doesn't solve the
`autoPatchelfHook` corruption.

### 3. `autoPatchelfHook` runs before `postFixup`

The hook corrupts the binary during `fixupPhase` before any wrapper script
touches it. Wrapping a broken binary doesn't help.

### Attempted DIY derivation (failed)

```nix
# This does NOT work — documented for reference
stdenv.mkDerivation {
  # ...
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper autoPatchelfHook ];  # autoPatchelfHook breaks it
  buildInputs = [ stdenv.cc.cc.lib glib ];               # glib is unnecessary
  installPhase = ''
    tar xzf $src
    install -m755 opencode $out/bin/opencode
  '';
  postFixup = ''
    wrapProgram $out/bin/opencode \
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
  '';
}
```

**Result**: `opencode` outputs Bun help text, not the TUI.

---

## Explored Alternatives

### dan-online/opencode-nix (community flake)

- **Claim**: "Always up-to-date" via auto-bumping
- **Reality**: pinned to v1.14.33 (older than nixpkgs v1.15.10)
- **Verdict**: stale, not maintained actively enough

### Official flake (anomalyco/opencode)

- **Approach**: builds from source via Bun (same as nixpkgs)
- **Pros**: tracks latest version, official source
- **Cons**: heavy build machinery (FOD with architecture-specific hashes,
  TypeScript scripts), slow rebuilds, tracks `dev` branch (potentially unstable)
- **Verdict**: viable but overkill for a terminal tool

### nixpkgs (current)

- **Approach**: builds from source, ships as `pkgs.opencode`
- **Pros**: stable, maintained, works out of box (minus the wrapper)
- **Cons**: lags behind upstream releases
- **Verdict**: best tradeoff for reliability

---

## Key Learnings

1. **Bun-compiled binaries are fragile on NixOS** — never use
   `autoPatchelfHook` or `strip` on them. If you need a pre-built Bun binary,
   use manual `patchelf --set-interpreter` only (no RPATH changes).

2. **`LD_LIBRARY_PATH` wrapper is the safest fix** for `libstdc++.so.6` — it
   runs at runtime, doesn't modify the binary, and works across versions.

3. **Community flakes can go stale** — always check the latest commit and
   version before adopting. The "auto-updater" claim doesn't guarantee
   freshness.

4. **Building from source is the only reliable NixOS path** for Bun-compiled
   apps. Pre-built binaries require either patching that breaks the runtime or
   workarounds that add complexity.

5. **The `libstdc++` issue persists across opencode versions** (1.10 → 1.15 →
   1.17) because it's a Bun build artifact, not a version-specific bug.

---

## Updating opencode

When nixpkgs updates opencode, `nix flake update` will pull the new version.
The wrapper stays the same — only the underlying binary changes.

To check the current nixpkgs version:
```sh
nix eval nixpkgs#opencode.version
```

To force an update:
```sh
nix flake update
sudo nixos-rebuild switch --flake ~/nixos-config
```

---

## Cross-References

- Wrapper fix documented in: `upgrade-26.05.md` (section 7)
- Provider persistence issue: `opencode-provider-persistence.md`
- Bun file watcher issue: [opencode #462](https://github.com/anomalyco/opencode/issues/462)
