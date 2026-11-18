---
name: audit-fix-round-plan-2026-11-18
description: Full 3-way repo audit 2026-11-18 (main @ 52fb729) + user-approved
  fix plan (all 4 batches + preload-ng removal, VMs skipped, backups deferred) —
  ExitPlanMode DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_62d216a2-b12e-422e-99ab-51bc34928d0c
---

Repo audit 2026-11-18 via 3 parallel Explore agents (NixOS side / home side / services side), P1s hand-verified. Verdict: fleet unusually healthy — no deprecated NixOS options, no eval breakage, impermanence near-complete, debt is accretion not architecture. 4 genuine P1s found.

**User decisions (AskUserQuestion):** ALL four fix batches approved (P1 fixes + EOL swaps + runtime hygiene + code/docs hygiene); preload-ng REMOVE; backups DEFER again (now #1 structural item, 3rd deferral); VM battery SKIP.

**Approved plan (NOT executed — ExitPlanMode denied):**
- P1a docker-image-refresh stranded-skip (docker.nix:396-405): compare RUNNING container image (`docker inspect -f '{{.Image}}' <name>`) vs fresh store ID, not store-vs-store; transcode-skip then self-heals next Sunday. Drop script-local `docker image prune -f` (autoPrune --all already covers).
- P1b media-import prune data-loss (media-import.zsh:243): unrar failures swallowed (`zsh-functions.zsh:92`) → failed sets get bulk-deleted; fix = failed-set tracking + prune refuses failed dirs; extend match to `*.r[0-9][0-9]`.
- P1c install.sh:364 `rm -rf .git` still present → `git checkout -B main $PINNED_COMMIT` instead of detach+rm (autoUpgrade pull --ff-only wedges on fresh installs).
- EOL: p7zip→7zip (terminal.nix:466); alertmanager `match.severity`→`matchers` (monitoring.nix:231, deprecated since 0.22); preload-ng removal (flake.nix:41-44, latitude default.nix:119-128, update-safe/bump.yml safe-input lists, host-units-smoke test).
- Runtime hygiene: Restart=always ×4 containers (module default on-failure strands exit-0 until Sunday); cadvisor healthcheck (probe image for wget/curl first — image may lack both); sandbox alertmanager-ntfy-bridge (monitoring.nix:315, only custom unit with zero hardening).
- Code/docs: zcode desktop entry single-owner at hosts/yoga/home.nix (`zcode-unmax --no-sandbox %u`, fixes %U) — delete mkForce block from home/niri.nix:601; niri.nix:27 unguarded `builtins.head` needs battery-refresh-style mode assert; mediaLane single-source via `@mediaLane@` + lib.replaceStrings on both readFiles (default.nix:21,166); recently-used.xbel = only persistence gap; fzf via programs.fzf (integrations OFF, palette stays in FZF_DEFAULT_OPTS); dead asserts delete (power-tlp:20, sops:56); mkForce→plain (secureboot:28, oomd:39); theme.nix gtk.css/cursor removals ONLY if home-files byte-diff clean; retired-stack comment sweep ~10 files; flake.nix:68/99 comments undercount (4 nixpkgs evals: base+noctalia+greeter+opencode).
- Verify: nix fmt explicit files, zsh -n/bash -n, targeted nix evals, home-files byte-diff, test-suite fast; NO commits; user runs sops rekey (latitude.yaml + nix-media.yaml still on RETIRED admin key = remaining P1) + switches.

**Audit facts worth keeping:** silo family-setup unreproducible from repo (IDs only live/API+memory); caddy/monitoring/media-import/niri-session in no VM test; ntfy rides public ntfy.sh (topic=only bearer); cadvisor only container without healthcheck yet drives ContainerDown; NM-wait-online stub + nas hostname literal + ~9 of 14 2026-10-04 P3 items still open; preload-ng lock 2026-01-14 (10mo); flake-compat ×2 transitive; api.key 0644 (gitignored, untracked — not a leak).

Related: [[audit-fixes-2026-11-15]], [[audit-fix-round-2026-10-31]], [[media-import-orchestrator-2026-11-17]], [[silo-trial-nix-media-2026-11-15]]
