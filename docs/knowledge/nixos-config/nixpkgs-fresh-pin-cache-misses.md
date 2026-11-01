---
name: nixpkgs-fresh-pin-cache-misses
description: Day-old nixpkgs pins → cache.nixos.org 404 → local compiles are
  NORMAL; always-local derivations + diagnostics (narinfo curl, dry-build)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_05f7e930-8696-43f6-84e7-62d568c3b23d
---

2026-09-17: user asked why yoga rebuilds "consist of a lot of building". Diagnosis: flake pin `4c78701` = nixpkgs 2026-09-16 (~1 day old) → Hydra hadn't uploaded the new store paths yet → Nix compiled `xwayland-24.1.13` and `tlp-1.9.1` from source (both verified 404 via `curl -s -o /dev/null -w "%{http_code}" https://cache.nixos.org/<hash>.narinfo`); `brave` log lines = prebuilt .deb repackage (no compilation, slow unpack/fixup of ~1 GB). Whole build: 2m44s — nothing was wrong.

**Why:** this repo tracks unstable via frequent flake input bumps; a fresh pin always costs a few local builds until the binary cache catches up (~1–2 days). Build noise ≠ problem.

**How to apply:**
- A fixed set of derivations ALWAYS builds locally by design, even fully cached (seconds each, just verbose): `security-wrapper-*`, `nixos-version`, `uname`, `nixos-generate-config`, `fc-cache`/`fontconfig-etc`, `greetd.toml`, `fish_patched-completion-generator`, `udev-rules`, `hwdb.bin`, `man-cache`, initrd assembly, `system-path`, `user-environment`.
- Big `linux-zen>` log output is usually initrd module-closure copying, NOT a kernel compile (kernel store path already built) — look for `CC [M]`/gcc lines before concluding a kernel build.
- The pinned `ryzen-smu` out-of-tree module rebuilds on every zen kernel bump — expected, tiny.
- Prove a cache miss with the narinfo curl above (hash only, before the first `-`); preview cost with `nixos-rebuild dry-build --flake .#<host>` ("these N derivations will be built" vs fetched).

Related: [[yoga-hibernate-status]] (zen kernel + ryzen-smu pin), [[hyprland-dms-setup]] (the 2026-09-17 build this came from).
