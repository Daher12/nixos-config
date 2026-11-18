---
name: audit-fixes-2026-11-18
description: Audit round 2026-11-18 EXECUTED — 4 P1 fixes (image-refresh
  stranded-skip, prune data-loss guard, install.sh .git wedge, sops rekey still
  user-run) + preload-ng removed + hygiene; fast green, COMMITTED 2026-11-19
metadata:
  node_type: memory
  type: project
  originSessionId: sess_62d216a2-b12e-422e-99ab-51bc34928d0c
---

Audit 2026-11-18 (main @ 1c5cb78; 52fb729 was stale — a parallel knowledge-sync commit landed mid-audit). 3 parallel Explore agents + hand-verified P1s. Verdict: fleet healthy, debt accretional. Executed per user-approved plan; committed 2026-11-19 (30 files). test-suite fast green; VM battery SKIPPED by user decision (changed code is unit-script content VMs never execute).

**Why:** second full audit round; [[audit-fixes-2026-11-15]] left 9 P3 backlog items + new media-import stack introduced fresh P1s.

**How to apply:**
- **1a refresh fix (docker.nix):** compare RUNNING container image (`docker inspect -f '{{.Image}}' <container>`) vs pulled store ID — store-vs-store let a transcode-skip strand jellyfin on the old image forever (comment's "retried next run" could never fire). Container name = 3rd arg. Also dropped script-local `docker image prune -f` (autoPrune --all covers it).
- **1b prune guard (media-import.zsh + zsh-functions.zsh):** unrarall now sets global `UNRARALL_FAILED` (absolute paths, cleared BEFORE early return); orchestrator accumulates `EXTRACT_FAILED` (typeset -Ua) → stage_prune excludes failed dirs, covers `*.r[0-9][0-9]` siblings, and prune scope == extract scope (lane top + first-level subdirs ONLY — old recursive find deleted never-extracted depth-2 archives). Smoke-tested in /tmp with fake lane.
- **1c install.sh:** `checkout -B main "$PINNED_COMMIT"`, .git KEPT (nixos-upgrade pulls --ff-only hourly; rm -rf .git wedged fresh installs).
- **2c preload-ng REMOVED** everywhere: flake input + lock node, latitude services block, update-safe + bump.yml input lists, host-units-smoke args/imports, README/REPO_OVERVIEW rows. `nix flake lock` prunes orphaned nodes automatically.
- 3a `Restart = mkForce "always"` on all 4 docker units — oci-containers module PLAIN-sets on-failure (nixpkgs oci-containers.nix:539), so plain value = eval conflict; mkForce required. 3b cadvisor healthcheck `wget -q -O- http://localhost:8080/healthz` (image has busybox wget, no curl — LIVE-PROVEN via ssh nix-media). 3c bridge unit got the standard sandbox set.
- 4a zcode desktop entry single owner = hosts/yoga/home.nix with `exec = if config.desktop.niri.enable then "zcode-unmax --no-sandbox %u" else "zcode --no-sandbox %u"` — niri.nix mkForce deleted; home-files PROVES identical output on niri attr. 4b niri panel mode: guarded `throw` NOT HM assertion (eval-time crash beats activation-time assertions). 4c mediaLane single-source: `@mediaLane@` placeholders + lib.replaceStrings in default.nix (3 literal sites → 1). 4d `.local/share/recently-used.xbel` persisted — ⚠️ initially MISFILED under directories (a file path there gets a directory bind-mounted over it); caught by the user-requested verification pass via `nix eval home.persistence."/persist".files`, moved to `files`, re-proven. 4e programs.fzf with all integrations false (module default-true for fish would double-inject). 4f dead asserts (power-tlp, sops) removed; secureboot/oomd mkForce→plain (loud conflicts); theme.nix gtk4 mkForce-false block + cursorPkg double install removed — PROVEN clean by diff.
- **2a p7zip swap NOT APPLICABLE:** locked 26.05 nixpkgs has NO `7zip` attr (verified `nix eval .#…pkgs.7zip.version` errors); p7zip 17.06 = p7zip-project fork = newest in-tree.
- **LORE (probe-caught, all in the prune guard):** script-level `no_unset` makes `${assoc[key]}` on missing key a HARD ERROR — use `${assoc[key]-}`; embedded `"${^empty_array}"` inside a larger quoted string yields ONE bogus word (`"$PWD/"`), not zero — guard with `(( ${#arr} ))`.
- **Diff-proof method (worktree):** `git worktree add /tmp/x HEAD` → build `.home-files` from both trees → `diff -rq`. Only store-hash refs (fontconfig/manpath→home-manager-path) + intended deltas should appear; xdg.desktopEntries entries live in home.PACKAGES not home-files — check via `nix eval home.packages --apply outPath list` diff too.
- **Verification pass 11-18 (user-requested, after "all green"):** findings re-proven vs ground truth (maintenance.nix:37 pull premise; retired age1vzw0xw… still sole operator recipient on BOTH yamls, current admin keys age1ff0ly…/age12eq9rt… absent); docker ID-format compatibility LIVE-proven (`docker inspect -f '{{.Image}}'` == `image inspect -f '{{.Id}}'` on both jellyfin+cadvisor); unrarall ledger unit-tested with a STUBBED unrar function (failed extract + collision-skip + collision-target all land in UNRARALL_FAILED); deployed nix-media toplevel BUILT and payloads grepped (0 placeholder leaks, guard shipped); yoga-GNOME attr diff-proofed too (%u-only delta). fast re-run green after the xbel fix. LORE: grep -c 'refresh ${' inside a compound bash command misreported 0 (quoting interaction) — verify greps with a Read when a count contradicts expectations.
- **Opencode:** pin still v2.2.4; v2.3.0/2.3.1/2.3.2 ALSO gate-broken (checked 2026-11-18, comment in flake.nix updated) — six consecutive broken releases.
- **USER-RUN follow-ups:** sops rekey latitude.yaml + nix-media.yaml to current admin key (P1 still open, .sops.yaml:18); `nus yoga switch` + `nus nix-media switch`; post-switch verify `systemctl cat docker-image-refresh` + docker healthcheck on cadvisor.
- Recorded NOT fixed: backups absent (deferred 3rd time — top structural item), silo family-setup unreproducible from repo, VM gaps (caddy/monitoring/niri), 4 nixpkgs evals (comments now count correctly), deliberate items untouched (grafana key, 0.0.0.0 binds, NFS export, brave basic keystore).

Related: [[audit-fixes-2026-11-15]], [[audit-fix-round-2026-10-31]], [[media-import-orchestrator-2026-11-17]], [[silo-trial-nix-media-2026-11-15]]
