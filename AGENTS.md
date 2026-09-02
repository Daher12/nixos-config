# AGENTS.md

Instructions for AI coding agents (opencode and others) working in this repository.

## Repository purpose

Personal NixOS flake configuration for three hosts: **yoga** (primary laptop),
**latitude** (legacy laptop), **nix-media** (media server). Read
`README.md` for the feature overview and `REPO_OVERVIEW.md` for a detailed,
per-file map of the repo (including known pitfalls).

## Layout

- `hosts/<name>/` — per-host NixOS modules (`default.nix`, hardware/disks, home-manager user config in `home.nix`)
- `home/` — shared home-manager modules (browsers, git, terminal, theme), imported via `../../home`
- `modules/`, `features/`, `core/` — shared NixOS option modules
- `profiles/` — hardware/system profiles
- `pkgs/` — custom nix packages (e.g. `mikromcp.nix`)
- `secrets/` — sops-nix encrypted secrets (hosts/yoga.yaml, hosts/latitude.yaml, hosts/nix-media.yaml)
- `scripts/` — helper scripts (`update-safe` is the safe rebuild path, exposed as the `nus` fish function)
- `lib/` — flake library functions

## Conventions

- Flake-based: `nixosConfigurations` per host, home-manager integrated per user.
- Module style: 4-attr function headers (`{ config, lib, pkgs, ... }:`), nixfmt formatting, option-based feature toggles under `custom.*` or `features.*`.
- Impermanence is in use: user state must be explicitly persisted via `home.persistence."/persist"` or `environment.persistence."/persist/system"`. If you add a program that writes state to `$HOME`, add the corresponding persistence entries.
- Secrets never go into plain files — use sops-nix (`secrets/`, `.sops.yaml`). Never commit plaintext keys; `api.key`-style files must stay out of commits.
- Package overrides that fix runtime issues should carry a comment explaining why (see the opencode `LD_LIBRARY_PATH` wrap in `hosts/yoga/opencode.nix`).

## House rules

- NEVER commit, push, or create PRs unless the user explicitly asks.
- Run `nix fmt` on changed `.nix` files and validate with `nix flake check` (or a dry-build of the affected host) before finishing.
- Prefer editing existing modules over creating new ones; follow the existing naming (`enable` options, `mkEnableOption`).
- Rebuild/testing: use `scripts/update-safe` guidance or `nixos-rebuild` with `--flake .#<host>`; do not run `nixos-rebuild switch` or reboot without asking.
- The `result` symlink and `.gcroots`-style artifacts are build outputs — ignore them, never commit them.
- Flake evaluation (and `nix fmt`, `nix flake check`, `nixos-rebuild --flake .#<host>`) reads the file from the **git index**, not the working tree. Newly created files are invisible to these commands until staged: run `git add <newfile>` first (staging only — never commit unless asked). Symptom if forgotten: `error: getting status of '/nix/store/...-source/<file>': No such file or directory`.
- The flake formatter's bare invocation (`nix fmt`) pipes stdin and fails with `unexpected end of input` — pass files explicitly: `nix fmt <changed .nix files>`.

## Verification workflow (QC)

Proven recipe for validating changes without a full rebuild:

- **Extracted/moved config must be proven behavior-preserving.** Build the home-manager files tree and diff the generated file against the deployed one:
  `nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home-files --no-link --print-out-paths`
  then `diff ~/.config/opencode/opencode.json <store-path>/.config/opencode/opencode.json`. A byte-identical diff means the refactor is safe.
- **Inspect generated config values with `nix eval --json`** (e.g. persistence entries: `nix eval --json .#nixosConfigurations.yoga.config.home-manager.users.dk.home.persistence."/persist".directories --apply 'map (d: d.directory or d)'`) instead of grepping source.
- **Dry-build is the acceptance gate:** `nixos-rebuild dry-build --flake .#<host>` after every structural change.

## Lessons learned (don't repeat)

- **Cross-references must be verified, not assumed.** AGENTS.md once pointed at a `REPO_OVERVIEW.md` § section that didn't exist — check the actual section heading (it is `## Known Gotchas`) before referencing it.
- **Keep REPO_OVERVIEW.md in sync when moving code.** It is a per-file map; if a fix/config moves modules (e.g. opencode wrap from `home/terminal.nix` to `hosts/yoga/opencode.nix`), update its file references in the same change, or it rots.
- **Staging is idempotent but not sticky for later edits.** `git add` a new file, then editing it again still leaves the flake reading the *staged* content — re-run `git add` after every subsequent edit of a new file before validating.

For deeper troubleshooting context, see `REPO_OVERVIEW.md` § Known Gotchas (e.g. opencode `libstdc++.so.6` fix, TLP wifi powersave roaming notes).
