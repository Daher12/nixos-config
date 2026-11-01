---
name: fleet-automation-review-exec-2026-10-19
description: Full-repo review executed + staged — nix-media pull fix, ci.yml,
  declarative SSH keys, is-on-ac dedup, libva lift, update-safe --pin,
  hygiene+docs; QC all green; sops rekey handed to user
metadata:
  node_type: memory
  type: project
  originSessionId: sess_bbb3e35b-2a91-4a0f-9758-01646d6da3d7
---

Review + remediation EXECUTED and STAGED 2026-10-19 (on top of the parallel docs-hygiene staging; flake.lock untouched, nothing committed, no switch). Review verdict: repo structurally strong; the one real breakage was nix-media's autoUpgrade.

**Executed (all staged, QC green):**
- **nix-media pull fix** (`hosts/nix-media/maintenance.nix`): `nixos-upgrade` got `ExecStartPre = runuser -u dk -- git -C /home/dk/nixos-config pull --ff-only` + `GIT_TERMINAL_PROMPT=0`. Verified against nixpkgs auto-upgrade module source @locked rev: NO git pull upstream → without this the daily 05:00 run re-staged a static tree forever. Failure → hourly restart + ntfy (already wired) + weekly-reboot aborts.
- **ci.yml** (new `.github/workflows/ci.yml`): push(main)/PR gate, same verify steps as bump.yml (flake check + dry-build all 4 attrs). Active only after push.
- **Declarative SSH keys**: new `core.users.authorizedKeys` option (modules/core/users.nix → `users.users.dk.openssh.authorizedKeys.keys`, additive via /etc/ssh/authorized_keys.d); yoga's dk@yoga ed25519 pubkey set on nix-media (real sshd :26) + latitude. yoga deliberately empty.
- **is-on-ac dedup**: new `pkgs/is-on-ac.nix` (overlay 1), battery-refresh.nix + ryzen-tdp.nix call it at their single use sites. QC: both script pre/post diffs = exactly PATH+call-site change; live compare old-vs-new on yoga MATCH (battery case; AC branch same verbatim comparison).
- **libva-utils** → profiles/laptop.nix (was duplicated in both laptop hosts).
- **update-safe `--pin <input>`** (repeatable; lucid excluded by policy/doc); `nus` moved hosts/yoga/home.nix → home/terminal.nix (both laptops now; yoga home-files byte-diff: only battery-refresh.service changed, nus.fish identical); `system.configurationRevision` in mkHost (evals to dirtyRev); opencode `pkgs.system`; home/default.nix dead default dropped; README (nightly→daily 05:00, CI section, --pin), AGENTS.md option-namespace line, REPO_OVERVIEW synced (CI/CD section, users.nix/ryzen-tdp/battery-refresh/laptop rows, update-safe section, manual-pins intro).

**QC run**: nix fmt; flake check (statix/deadnix/nixfmt) green; dry-build all 4 hosts green; eval checks (ExecStartPre, authorizedKeys, configurationRevision, libva) green; update-safe arg-parse + set -u expansion tests green; ci.yml YAML parse via devshell yq green.

**Independent QC re-verification pass (second user request) — all green, deeper proofs**: worktree==index for all 20 touched files; sshd `AuthorizedKeysFile` includes `/etc/ssh/authorized_keys.d/%u` and the BUILT store file (`dk-authorized_keys`) contains exactly the yoga key on nix-media+latitude (yoga: none); nixos-upgrade unit `After=network-online.target` (pull never races network), Restart/RestartSec/TimeoutStartSec survived the attrset restructure; single ExecStartPre proven (one repo definition + upstream defines none); libva eval-true on yoga/yoga-gnome/latitude; nus present on both laptops and yoga's built `nus.fish` BYTE-IDENTICAL (cmp) after the move; only intentional `is_on_ac` mentions remain (package comment + REPO_OVERVIEW row).

**Eval-tooling gotchas hit during QC** (not config bugs): (1) `nix eval` fails "store path … contains illegal character ' '" when printing values whose context spans MULTIPLE store paths (git+util-linux in the ExecStartPre string) — flaky/nondeterministic; workaround = `--apply 'l: builtins.elemAt l 0'` + `--raw`, or source-level proof. (2) HM `programs.fish.functions.<name>` is a plain string — `.body` attrpath errors ("cannot coerce null"). (3) JSON eval can't serialize multi-output drv context at all.

**Corrections to the review**: the `/var/db/sudo/lectuted` "typo" was an Explore-agent misreport — the file always said `lectured`; nothing fixed there. Tailscale SSH to nix-media (tagged device) needs periodic browser re-auth → that's why declarative keys/port-26 matter for automation.

**Pending**: user switch (nix-media's pull fix only lands with its next switch/reboot; laptops per [[yoga-switch-unit-failures-2026-10-18]]); sops rekey (SOPS_RUNBOOK §3) is user-run — after it: move `litellm_config` from nix-media-litellm.yaml into nix-media.yaml, rewire `hosts/nix-media/default.nix:62`, delete side file; ci.yml activates on next push. Backups (restic) deliberately skipped per user decision 2026-10-19.
