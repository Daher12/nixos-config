---
name: git-file-ref-branch-testing
description: Build/switch an unpushed local branch without git checkout —
  git+file://?ref= URI reads the branch's committed tree
metadata:
  node_type: memory
  type: reference
  originSessionId: session_136694fc253dd290e00cad77845d4064
---

Test a local-only branch (vps/dux-shell/niri-testing are all unpushed) WITHOUT touching the working checkout:

```
nix build 'git+file:///home/dk/nixos-config?ref=niri-testing#nixosConfigurations.yoga-niri.config.system.build.toplevel'
sudo nixos-rebuild switch --flake 'git+file:///home/dk/nixos-config?ref=niri-testing#yoga-niri'
```

Verified live 2026-11-06 (attr lists resolve per branch). Semantics: `?ref=` reads the branch tip's **committed tree only** — unlike `--flake .` (git index), uncommitted/staged edits are invisible, so commit before rebuilding to pick up fixes. Quote the URI (bash globs `?`). Rollback = `nixos-rebuild rollback` or `--flake /home/dk/nixos-config#yoga` (main). Attr per branch: niri-testing → `yoga-niri`; dux-shell → plain `yoga` (its profile flips dms.enable default); vps → `vps`. For edit-rebuild iteration use `git worktree add ~/nixos-config-<name> <branch>` instead. `build-vm` from these refs is NOT useful — impermanence/sops aren't stubbed in a bare VM (repo VM tests inject a sops stub for that reason); the live yoga switch is the real smoke test. Related: [[branch-split-vps-dms-niri-2026-11-06]], [[desktop-switch-architecture-2026-10-13]].
