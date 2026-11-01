---
name: coreutils-modernization-audit-2026-09-19
description: Audit 2026-09-19 — modern CLI tools installed but ZERO aliases (eza
  dead, fish ls still GNU 9.11), fzf binary missing despite loaded fzf-fish
  plugin; uutils verdict = SKIP
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7d04bf39-2669-4c2e-9f2c-da97821d356f
---

Read-only audit on yoga 2026-09-19 (user asked to "check the state of the coreutils I switched and the corresponding aliases"). No changes made.

Findings (runtime-verified in fish, not just source-grepped):

- `home/terminal.nix` installs eza/ripgrep/fd/sd (+btop/fastfetch via programs.*) but the repo has ZERO shellAliases/shellAbbrs/fish functions (only `nus` in hosts/yoga/home.nix). fish `ls` goes through fish's own color wrapper to **GNU ls 9.11** — eza is installed but dead unless typed explicitly.
- **BROKEN:** `fzf` binary absent from PATH while the `fzf-fish` plugin is loaded (terminal.nix plugins list) and `FZF_DEFAULT_OPTS` is set in interactiveShellInit — the plugin's Ctrl-R/Ctrl-F keybindings error at runtime. Suspected pre-baseline leftover that worked when fzf came from outside the flake.
- Not installed at all: bat, dust/dua, duf, procs, tealdeer. fd/rg/sd/zoxide-as-`z`/btop/delta (git integration) are fine as standalone commands — that's their intended UX, no alias needed.

uutils coreutils (Rust; what Ubuntu 25.10 ships) verdict: **SKIP**.
- System-wide swap: unsanely risky on NixOS — this repo execs `${pkgs.coreutils}/bin/...` directly in ~7 places (impermanence initrd, ryzen-tdp.nix, yoga-s2h.nix, monitoring.nix, mnamer.nix, battery-refresh.nix, nix-media maintenance.nix).
- Interactive addition: pointless — uutils' goal is GNU-identical behavior (no batteries); the value is all in the eza/bat/fd tier.

Fix OFFERED, not staged, awaiting user go-ahead: in home/terminal.nix — `programs.eza.enable` (fish integration gives ls/ll/la aliases), `programs.fzf.enable` (revives dead plugin), `programs.bat.enable`, optionally dust/duf/procs in home.packages; gate with dry-build per house rules. See [[ask-dont-infer-system-state]] for the runtime-verification caution that shaped this audit.
