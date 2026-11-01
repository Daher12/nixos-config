---
name: audit-fix-round-2026-10-31
description: EXECUTED+QC green STAGED — audit fix round (CI gate+SHA pins, flake
  dedup w/ 13,936-drv proof, module polish, docker digest-refresh, monitoring
  alerts+hardening); dockerd log-opts crash caught by VM gate
metadata:
  node_type: memory
  type: project
  originSessionId: sess_181225f0-17b3-4856-8a75-12d912cd6352
---

# Audit fix round 2026-10-31 — EXECUTED + QC GREEN + STAGED (uncommitted)

Resumed after an executor died mid-round; finished batches A/B/C/E/F/G/H (D skipped
by user: NFS `*` export `modules/roles/media.nix:42` + Grafana docs-sample
`secret_key` `monitoring.nix:243` remain OPEN). Mixed in index with user's parallel
lucid-1.20.5.5/opencode-v2.2.4 sweep (flake.lock, home/lucid.nix, patches, zcode).

**Batch B proof:** literal drvPath cmp impossible (any flake.nix edit churns the
source snapshot + configurationRevision). Differential proof instead: probe repo
/tmp/opencode/probeB (pre-B 687314a / post-B bcecb36), refined_graph_diff.py pairs
all 13,936 drvs by basename, masks store hashes + both commit SHAs →
`REFINED-GRAPH-IDENTICAL-MODULO-HASH-TOKENS-AND-COMMIT-REVS`.

**C4 proof:** mnamer-tools outPath EQUAL pre/post refactor (9pb9fid1…) — merged
ignore list feeds settings derivation env, so identical list ⇒ identical outPath.

**⚠️ Lore (all QC-pass-verified or VM-gate-caught):**
- **NixOS `path` option auto-appends coreutils/findutils/GNUGREP/gnused/systemd** to every service PATH — bare `grep`/`sleep`/`systemctl` in units resolve WITHOUT explicit path (why ntfy-failure@ always worked). procps/gawk are NOT in the default set (weekly-reboot adds them for pgrep/awk).
- **pipeline VM test scope = maintenance+ntfy+docker+mediaRole modules ONLY** (tests/nix-media-pipeline.nix:55-61) — monitoring.nix is NOT imported: alert rules, intel-gpu-metrics hardening, bridge service are NOT VM-covered. Also containers are stubbed; docker-image-refresh is content-grepped, never RUN. "VM green" ≠ those proven.
- **promtool is NOT in nixpkgs prometheus 3.12** (bin has only prometheus+migrate). Rule validation fallback: regex compile-check + structural parity with pre-existing rules; true validation = prometheus first start after switch (loud failure).
- **nix-media GID pin values**: config-side eval pre-pin = video 26 / render 303 (nixpkgs defaults) — pin is no-op; comment accurate.
- **json-file log-opts CRASH dockerd on NixOS**: module defaults `log-driver="journald"`; `max-size`/`max-file` are json-file-only → dockerd fails to start (pipeline VM caught). Container logs were NEVER unbounded (journald caps apply) — audit finding was wrong for NixOS. Do not re-add log-opts.
- **Nix `''` strings: `\\.` = TWO literal backslashes** (probe-verified). Prometheus regexes in `''` strings need single `\.`. Eval `--raw --file` probe is the cheap test; bash single-quoting eats `''` in `--expr`.
- **`<<'EOF'` heredocs inside '' strings survive uniform reindentation** (common-indent strip) — windows11-icon C7 refactor build-proven: SVG renders valid, terminator at col 0.
- `virtualization.nix` guest attrset must keep `inherit launcher;` — guestPackages consumes it (flake check caught the drop).
- statix flags ≥3 repeated `users.*` keys → consolidate to `users = { users… groups… }`.
- `nix build <drv-path>` may print the DRV, not the output; use `nix derivation show` → outputs.out.path.
- `ssh nix-media` = Tailscale browser re-auth wall for agents (timeout 124, login URL in output) — live pre-checks stay USER-RUN.

**USER-RUN follow-ups:** sops rekey `secrets/hosts/nix-media.yaml` (SOPS_RUNBOOK §3)
→ then fold litellm side file + ntfy topic/url dedup; restic backups (deferred);
post-switch: `getent group video render`, `docker exec audiobookshelf curl --version`.
Deferred defects: Batch D two items; update-safe has no `--help` flag (usage via
error path — pre-existing); `with pkgs;` in maintenance.nix:52 left as-is.

Gates on FINAL state: flake check 0, dry-builds ×3 0, host-units-smoke PASS,
nix-media-upgrade-pipeline PASS (247s), alert yaml realized w/ `\.service`.
