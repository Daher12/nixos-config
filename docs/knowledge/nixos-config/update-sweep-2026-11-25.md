---
name: update-sweep-2026-11-25
description: Pkg bump sweep EXECUTED + VERIFIED (b411f15+e98d1d7, UNPUSHED) — zcode 4.0.0,
  mikromcp 1.18.0, opencode pin RESUMED v2.4.1; kernel NOT moved by this sweep; fetchurl
  hash = FLAT (nix hash path = NAR) — earlier "CDN client-dependent bytes" lore RETRACTED
metadata:
  node_type: memory
  type: project
  originSessionId: sess_0040c936-396f-4ae7-8b28-ac26e21f7748
---

Update sweep executed 2026-11-25, then independently verified same day (user: "verify update sweep (without vm tests)"). Flow: user wanted findings before committing → manual `nix flake update` (NOT update-safe, which auto-commits), findings reported, two user-approved commits, both **UNPUSHED**: **b411f15** (flake.lock only) + **e98d1d7** (zcode, mikromcp, opencode pin, flake.nix comment, REPO_OVERVIEW). Pre-existing mnamer/docs staging untouched.

**Safe inputs (lock diff vs cbf7416: exactly 6 nodes moved, 15 of 21 byte-identical):** nixpkgs ab5c18f→**0dc498b** (11-22, 185 commits), home-manager 5643e73→**6480d7d** (2 commits: lock bump + CI action, no module change), sops-nix 7c637af→**d5abe5e** (1 CI commit), nixos-hardware 3347596→**97a30ee** (9 commits, only apple/t2 + raspberry-pi README), opencode + its nixpkgs_4 (3181085→e21fec3). disko/impermanence unchanged.

**Kernel: this sweep did NOT move it.** zen 7.3.5 was already in the tree from the 11-20 CI bump (ab5c18f); the running system (gen 211, 11-19, f684076) is 7.3.4 → next switch + reboot lands 7.3.5. latitude 7.3.5 / nix-media 6.18.64 unchanged. ryzen-smu override stays (nixpkgs stock 0.1.7-unstable-2025-10-22). ⚠️ To check the override eval `config.boot.extraModulePackages` (→ `["0.1.7-unstable-2026-08-15"]`); `boot.kernelPackages."ryzen-smu"` always evals the STOCK package.

**zcode 3.18.1→4.0.0** (user: "should be v4"). 4.0.0 is the only 4.x on the CDN (probed 4.0.0–4.0.9, 4.1.0–4.1.3, 4.2.0/4.2.1, 4.3.0, 4.4.0, 4.5.0; 5.0.0 → 404). Pinned hash verified against the vendor manifest: `releases/<v>/linux-x64/latest.yml` carries sha512 + size — compare with `openssl dgst -sha512 -binary FILE | base64`. AppImage layout and `StartupWMClass=ZCode` identical to 3.18.1; niri app_id (currently "zcode") can only be confirmed on first 4.0.0 launch.

**mikromcp 1.16.1→1.18.0.** Committed lockfile byte-identical to upstream @gitHead 17d64bb; tarball sha1 = registry `dist.shasum`; `serve` still the default subcommand; same 61 env names; routers.yaml/identities.yaml still supported (1.18.0 adds env-only single-router mode, `reload_config`, `MIKROMCP_READ_ONLY`). MCP `initialize` handshake OK. NOT tested against the real router config — `mikromcp doctor` after switch is the user-side check.

**opencode v2.2.4→v2.4.1 (gate passed).** 2.4.1 parses the generated opencode.json fully (`--standalone debug config`: model/permissions/providers/agents + `mcp.nixos` loaded, windows-mcp disabled). Wrapped binary `--version` OK. The ELF needs only glibc (2.2.4 identical) — the libstdc++ wrap is neither provable nor disprovable from `--version` (bun dlopens it lazily); kept as is. opencode's packageManager is now **bun@1.4.4** — flake.nix comment + REPO_OVERVIEW row still say 1.4.2. Behavior changes since 2.2.4: background subagents by default (2.3.0), timed-out shell commands keep running (2.3.1), new TUI theme (`opencode-classic` = old look), storage write path changed (back up `~/.local/share/opencode` before first 2.4.1 launch if rollback matters), automations opt-out `"automations": false`, MCP newest-protocol-first. Background service / `--standalone` already existed in 2.2.4 (not new). A 2.2.4 managed service runs on 127.0.0.1:13420; a 2.4.1 client in a foreign HOME fails "port 13420 already in use" → after switching, `opencode service restart` if the first launch complains. `opencode mcp list` prints "No MCP servers configured" on 2.2.4 AND 2.4.1 even when `debug config` shows servers loaded — misleading CLI, not a config problem.

**Held pins byte-identical:** noctalia c257324 (**v5.6.0 exists upstream**), greeter af0bf4b (**v1.7.1 exists**), lanzaboote c1c5edd (newest), spotx-nix e1b2c3c / spotx-bash db0583a (spotify-spotx 1.2.90.451 built green). nix-media does not install opencode (HM option default shows nixpkgs' own opencode 1.19.3 — never consumed); it only rides nixpkgs/HM/sops-nix.

**Lore — corrected during verification:**
- ⚠️ `fetchurl.hash` is the FLAT file hash. `nix hash path FILE` returns the NAR hash → a different value for the very same bytes → "hash mismatch". Use the FOD's `got:` line, `nix store prefetch-file <url>`, `nix hash file`, or sha256sum→SRI. The first-pass notes "cdn-zcode.z.ai serves client-dependent bytes" and "npm tarballs need curl -L" were BOTH this mistake — retracted; the CDN served byte-identical files to curl and nix. (e98d1d7's commit message still carries the false claim — see Open.)
- Verified TRUE: the flake source dir (`…-source`) is inside the system closure (5 of them) → any staged tracked-file change, docs included, changes the toplevel path. `nix eval …toplevel.outPath` after a staging change names a path not yet in the store → use `nix build --print-out-paths`. Also `nix path-info --no-size` is not a valid flag (its error, hidden by `2>/dev/null`, looked like an empty grep).
- Verifying the COMMITTED tree: `git+file://$REPO?rev=<sha>` → flake check + real yoga build there (it differs from the index, which carries the staged mnamer work). b411f15 alone is a non-evaluable intermediate (lock says opencode v2.4.1, its flake.nix says v2.2.4; nix re-locks in memory) — harmless while both commits travel together.
- Testing opencode versions safely: isolated HOME + XDG dirs with `--standalone` (private server). Without `--standalone` it tries to start the managed service on port 13420. Copy store files with `cp --no-preserve=mode` or `rm -rf` fails on read-only copies. Never `pkill -f` a pattern that occurs in your own command line.

**QC (all green):** `nix flake check` on the index AND on the HEAD tree (all 4 attrs); `test-suite fast` OK (yoga latitude nix-media); real yoga toplevel built from both trees (index `ih7nyikq…`, HEAD `hf1jpfhj…`); HEAD-tree dry-runs latitude/nix-media/yoga-gnome; closure has opencode-2.4.1+6f05140, zcode-4.0.0, mikromcp-1.18.0, linux-zen-7.3.5, ryzen-smu-7.3.5-0.1.7-unstable-2026-08-15, spotify-spotx-1.2.90.451.

**Open:** (1) fixup awaiting user OK — amend e98d1d7: drop the false CDN bullet from the message, bun 1.4.2→1.4.4 in the flake.nix comment + REPO_OVERVIEW row, "v2.4.0 superseded" → "not gate-tested"; (2) noctalia v5.6.0 + greeter v1.7.1 paired bump; (3) `git push` for nix-media's daily pull; (4) AGENTS.md knowledge-subdir list stale (4 documented, 6 tracked); (5) MEMORY.md index is over its size limit (last ~16 lines not loaded).
