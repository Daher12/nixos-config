---
name: nix-media-media-import-workflow
description: The nix-media extract→move→rename media workflow (aria2 + manual
  unrar + mnamer-tools) — manual, no automation; explained to user 2026-11-17
  after they forgot it
metadata:
  node_type: memory
  type: project
  originSessionId: sess_28fc01e0-fe23-4023-a791-04d1ae871a35
---

Explained 2026-11-17 (user had forgotten their own workflow). It is **manual tooling, NOT a daemon/timer** — three steps driven over SSH from `/mnt/storage/downloads`:

1. **Download**: `aria` **zsh function in an imperative `~/.zshrc` on nix-media** (NOT in the repo) — reads `/mnt/storage/downloads/links.txt`, daemonizes `aria2c -i links.txt -j2 -x8 -s8` with Chrome UA + falloc + mmap. ⚠️ aria2c saves to the **CWD** — must be run from the downloads dir (links file path is absolute, save dir is not).
2. **Extract**: `unrarall` **zsh function, same imperative `~/.zshrc`** — normalizes zero-padded multipart (`foo.part001.rar`→`foo.part1.rar`, collision-guarded), collects new-style `.part1.rar` + old-style `name01.rar` roots (guard: char before `01` must be digit/separator so `ShowE01.rar` isn't misdetected), single password prompt, extracts each root `unrar x -o+`. Deeply zsh-flavored (`emulate -L zsh`, extended globs `*.part0##<->.rar`, `$match[]`) — porting to bash would risk drift.
3. **Move + rename**: `mnamer-tools` wrapper (writeShellApplication in `modules/features/mnamer.nix`, options `features.mnamer.*`). Runs mnamer → TMDB lookup (language=de) → **moves + renames in one step** into `/mnt/storage/movies` / `/mnt/storage/shows` (also NFS-exported via roles.media; served by Jellyfin + Silo).

Commands: `import-test`/`movies-test`/`shows-test` (dry runs), `import` (real run), `import-safe`/`movies-safe`/`shows-safe` (`--no-guess`), `raw`, `source`, `path`, `dump`.

Naming: movies `{name} ({year})/{name} ({year}).{ext}`; shows `{series}/Season {NN}/{series} - S{NN}E{NN} - {title}.{ext}`. Config: batch+recursive, no_overwrite, video+subtitle mask (mkv/mp4/avi/srt/ass…), ignores samples/RARBG/.part/trailers (+host adds nfo, hits=8, --no-style at hosts/nix-media/default.nix:113).

Lore:
- Module deliberately has **no apiKeys options** — keys would land in a world-readable store path; if ever needed, render config from a sops secret (see features.litellm configFile pattern).
- replaceAfter: `@`→`at`, `;`→`,`; the `"&" = "and"` default was REMOVED 2026-11-17 (canonical titles keep `&` — scene "and" names were the batch failing Silo auto-matching, see [[silo-trial-nix-media-2026-11-15]]).

**HARVEST PLAN 2026-11-17 — APPROVED via AskUserQuestion → EXECUTED same day (see [[media-workflow-harvest-2026-11-17]] for execution state):** user chose "harvest verbatim into zsh init": new `hosts/nix-media/zsh-functions.zsh` with both functions byte-for-byte (from the user-pasted ~/.zshrc, minus the `# Created by newuser` header), referenced as `programs.zsh.interactiveShellInit = builtins.readFile ./zsh-functions.zsh;` in hosts/nix-media/default.nix (~line 113, next to mnamer block; no conflict — modules/core/users.nix sets zsh enable/ohMyZsh but NOT interactiveShellInit, NixOS merges). readFile chosen over inline Nix string to avoid ~20 `''${` escapes. git-add the new file before eval. Plus REPO_OVERVIEW.md row + knowledge record. Verify: nix eval `environment.etc."zshrc".text` grep for verbatim lines + test-suite fast nix-media; VM battery SKIP (text-only). User-side post-switch: `zsh -ic 'whence -v unrarall aria'`, THEN empty ~/.zshrc (strip-after-switch, per noctalia lesson). nix-media has NO impermanence — ~/.zshrc survives reboots but not reinstalls; nix-media shell = zsh + oh-my-zsh agnoster, ohMyZsh.plugins = [ ] (extract plugin NOT enabled — that's what user half-remembered). Plan-mode sandbox blocks ssh AND git log — couldn't inspect the live box.
