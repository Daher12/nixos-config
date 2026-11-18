---
name: media-workflow-harvest-2026-11-17
description: nix-media media pipeline (aria→unrarall→mnamer-tools) documented;
  ~/.zshrc shell helpers harvested verbatim into nix (staged, switch pending)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_28fc01e0-fe23-4023-a791-04d1ae871a35
---

Media workflow on nix-media — full pipeline, run manually from `/mnt/storage/downloads` (no daemon/timer):

1. **`aria`** — daemonized aria2c reading `/mnt/storage/downloads/links.txt`; saves to the **CWD** (links path is absolute, save dir is not — must be launched from downloads). 2 jobs × 8 conns, Chrome UA, `falloc`, TLS≥1.2.
2. **`unrarall`** — zsh function (extended globs, `emulate -L zsh`): normalizes zero-padded multipart names (`part001.rar`→`part1.rar`) with collision guards; collects roots from `.part1.rar` AND old-style `name01.rar` sets (guard: char before `01` must be digit/`.``_``-`, so `ShowE01.rar` never misfires); one password prompt; `unrar x -o+` per root.
3. **`mnamer-tools import`** — existing nix wrapper ([[audit-fixes-2026-11-15]] era module `modules/features/mnamer.nix`): TMDB-de lookup → moves/renames into `/mnt/storage/{movies,shows}`; `import-safe` = `--no-guess`. Jellyfin/Silo scan the libraries after.

HARVEST 2026-11-17 (user approved "harvest verbatim"): `aria` + `unrarall` lived only in imperative `~/.zshrc` on nix-media (no impermanence on that host — survived reboots, invisible to repo, which is why it was forgotten). Moved **byte-for-byte** (minus `# Created by newuser` header) into `hosts/nix-media/zsh-functions.zsh`, consumed via `programs.zsh.interactiveShellInit = builtins.readFile ./zsh-functions.zsh` in `hosts/nix-media/default.nix` — readFile avoids ~20 `''${` escapes; zsh-flavored code kept as zsh (bash port of extended globs = drift risk, rejected). nix-media shell = zsh+oh-my-zsh, `core.users.defaultShell = "zsh"` (users.nix sets plugins=[] — oh-my-zsh's own `extract` plugin NOT enabled; irrelevant now).

State: EXECUTED + staged UNCOMMITTED; `test-suite fast nix-media` OK + `nix eval` zshrc-content grep green (functions land at lines 50–150 of generated /etc/zshrc, byte-identical; NixOS places interactiveShellInit BEFORE plugin sourcing — harmless for function defs). ⚠️ GOTCHA hit during verification: `nix eval` on a dirty tree served a STALE eval-cache entry that failed with "store path … name longer than 211 characters" listing zsh-plugin drvs — phantom error, disappeared with `--option eval-cache false`; on this repo (parallel sessions + dirty tree) distrust eval-cache failures and re-run with the cache off before root-causing.

PENDING user-side: switch on nix-media (lands with the gen-202 batch), then `zsh -ic 'whence -v unrarall aria'`, then strip `~/.zshrc` AFTER the switch (strip-after-switch lesson, cf. [[noctalia-config-export-energy-2026-11-08]]).
