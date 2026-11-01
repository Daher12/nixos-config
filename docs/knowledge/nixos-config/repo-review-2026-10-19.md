---
name: repo-review-2026-10-19
description: Full repo review 2026-10-19 — findings, user decisions, and
  user-APPROVED execution order ("execute plan, include" 3 judgment-calls);
  ExitPlanMode denied twice → harness STUCK in plan mode, NOTHING executed.
  Ready-to-run batches A–F + implementation details in file.
metadata:
  node_type: memory
  type: project
  originSessionId: sess_bbb3e35b-2a91-4a0f-9758-01646d6da3d7
---

Maintenance-focused full-repo review 2026-10-19 (goal: low-maintenance, automation-maximal config). 3 Explore agents mapped flake/hosts/modules/automation; claims verified against official sources (nixpkgs auto-upgrade module @ locked rev 26f4107, lanzaboote v1.2.0 module, NixOS options index via nix MCP). Plan fully written, ExitPlanMode DENIED → nothing executed.

## User decisions (AskUserQuestion)
- Auto-update fix: **nix-media ONLY** (no laptop auto-update — yoga's clone is the dev tree, auto-pull would fail weekly)
- Backups: **SKIP for now** (finding on record; services.restic.backups verified available)
- SSH keys: **YES, make declarative** (core.users.authorizedKeys option + per-host pubkeys)

## Verified findings (prioritized)
- **P1: nix-media "daily auto-upgrade" can't receive updates.** `system.autoUpgrade.flake = path:/home/dk/nixos-config` — upstream nixos-upgrade script does NO git ops (pull removed years ago; only `--refresh`), and nothing else in the repo pulls on that host (only scripts/update-safe:48, manual). Daily 05:00 boot-stages a STATIC tree; CI bump.yml commits land on GitHub only. Fix (approved): ExecStartPre `runuser -u dk -- git -C /home/dk/nixos-config pull --ff-only` (+GIT_TERMINAL_PROMPT=0) on nixos-upgrade in maintenance.nix; runuser-as-root dodges git dubious-ownership; diverged clone → unit fails → existing ntfy push fires.
- **P1: no CI gate on push/PR** — only weekly bump.yml validates its own commit. Fix: ci.yml reusing bump.yml steps (nix flake check --impure + dry-build ×4 attrs).
- **P1: sops debt** — latitude.yaml + nix-media.yaml still encrypted to retired admin key; forces nix-media-litellm.yaml side-file. User runs SOPS_RUNBOOK §3 + moves litellm_config; agent rewires + deletes side file after.
- **P2: no authorized_keys managed anywhere in repo** (yoga key NOT in nix-media port-26 sshd — blocked live diagnostics).
- **P2: system.configurationRevision unset** (fix in mkHost: `self.rev or self.dirtyRev or null`).
- **P2: typo `/var/db/sudo/lectuted`** hosts/yoga/default.nix:368 → lecture resets every boot.
- **P2: `nus` fish fn only on yoga** → move to home/terminal.nix (byte-diff gate).
- **P3:** README:110 "nightly" vs daily 05:00; AGENTS.md says `custom.* or features.*` (reality core/features/hardware/roles; custom.* only home/opencode.nix); home/default.nix:4 dead default; home/opencode.nix:52 hardcoded x86_64-linux.
- Judgment-call (offered, not planned): HM option naming = 5 conventions (browsers.*/desktop.*/programs.terminal/opencode.enable/custom.*); is_on_ac() dup (battery-refresh vs ryzen-tdp); libva-utils dup → laptop profile; update-safe `--pin <input>` passthrough (batch F in plan).

## Verified NON-issues (do not re-flag)
- `services.journald.extraConfig` IS current — no `services.journald.settings` option exists at all.
- lanzaboote generations bounded: configurationLimit inherits boot.loader.systemd-boot.configurationLimit (mkDefault 10 in core/boot.nix); 2G ESPs on both laptops fine.
- No backups fleet-wide (user chose skip); laptop auto-update declined; Tailscale browser re-auth for tagged-device SSH = tailnet policy, out of repo scope.
- Strengths confirmed: single nixpkgs eval + one documented second (opencode), consistent NixOS namespaces, GC+optimise everywhere, guarded maintenance units, VM tests, accurate docs. 4 flake attrs (yoga, yoga-gnome, latitude, nix-media), nixpkgs 26.05 @26f4107.

Plan batches A–F + QC gates were fully written in the denied ExitPlanMode call — re-present or re-derive from this file. Related: [[repo-review-2026-10-16]], [[sops-identity-architecture-2026-09-13]], [[nix-media-tailscale-ssh-access]], [[plans-for-weaker-executor]].

## 2026-10-19 UPDATE: execution approved but BLOCKED by plan-mode trap
User then said **"execute plan, include:"** and added all three judgment-calls as IN-SCOPE: (1) is_on_ac() dedup, (2) libva-utils lift to profiles/laptop.nix, (3) update-safe `--pin <input>`. A second ExitPlanMode (plan + additions) was ALSO DENIED → **plan mode still active, NOTHING executed** (same sticky-plan-mode trap as [[zcode-shell-sandbox-etc]]: after a denial, Bash writes/nix builds stay blocked even after the user orders execution; only a later user-approved ExitPlanMode lifts it). Execution attempt blocked first on: `nix build .#...home-files` snapshot → "Plan mode only allows read-only, non-destructive tools".

## Implementation details gathered (all read, ready to execute)
- **Batch A**: maintenance.nix:15-19 nixos-upgrade.serviceConfig — add ExecStartPre runuser git pull --ff-only + `environment.GIT_TERMINAL_PROMPT = "0"`. File header is `{ pkgs, ... }:` (no mainUser in scope — hardcode dk or add arg).
- **Batch B**: ci.yml copies bump.yml steps (checkout@v5, install-nix-action@v31 w/ extra_nix_config, `nix flake check --all-systems --impure --keep-going`, dry-build loop over `nix eval --json '.#nixosConfigurations' --apply builtins.attrNames`), triggers push(main)+PR, no secrets, no commit step.
- **Batch C**: users.nix options.core.users += `authorizedKeys` (listOf str, default []) wired `users.users.${mainUser}.openssh.authorizedKeys.keys`; authorizedKeys.d/<user> is ADDITIVE to ~/.ssh/authorized_keys. yoga pubkey: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE900h7UUGyAcICSsxmX2xqEDcF1PTkonC/r9l3xroES dk@yoga` → set on nix-media + latitude only (not yoga itself); second key win11_vm_ed25519.pub is VM-only, skip.
- **is_on_ac dedup**: both copies semantically IDENTICAL (whitespace only); single use site in each (`if is_on_ac; then`). Design: `pkgs/is-on-ac.nix` writeShellApplication exit 0=AC/1=battery, wired into overlay 1 callPackage list (flake.nix:131-136), consumers add to runtimeInputs and call binary directly.
- **nus move**: hosts/yoga/home.nix:307-309 `programs.fish.functions.nus = ''"$HOME/nixos-config/scripts/update-safe" $argv'';` → home/terminal.nix mkIf cfg.fish.enable block; byte-diff gate via home-files build. Note nix-media imports only ../../home/git.nix → no nus there (fine).
- **libva lift**: hosts/yoga/default.nix:351 + hosts/latitude/default.nix:116 environment.systemPackages entries → profiles/laptop.nix (needs new environment block; yoga-gnome also inherits, fine).
- **update-safe**: usage `update-safe <host> [action] [--pin <input>...]`; append pins to the `nix flake update` line (safe inputs at :51-54); document safe pins (lanzaboote/opencode/quickshell/dank-greeter/spotx-nix; lucid needs LUCID_RUNBOOK).
- **SOPS_RUNBOOK §3 commands** confirmed: per-device `SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d … > /run/plain.yaml`, latitude-only yq del wifi keys, re-encrypt, verify recipients; runs ON the device (device key is a recipient, yoga's is not).
- **QC plan**: pre-change snapshots FIRST (home-files build + `nix eval --raw …ryzen-tdp-control.serviceConfig.ExecStart` + `…home-manager.users.dk.systemd.user.services.battery-refresh.Service.ExecStart` → nix build those store paths, expected post-diffs ONLY battery-refresh + is-on-ac call sites); git add before eval (33 files already staged by parallel hygiene pass — all `M ` = index==worktree, safe to edit+re-add); nix fmt with explicit files; flake check; dry-build ×4 attrs.
- **maintenance.nix weekly-reboot already verified**: guards (current==next, is-failed, ffmpeg/pgrep, load>2, uptime<3600) — do not touch beyond the ExecStartPre.
