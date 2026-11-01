---
name: repo-audit-fix-plan-2026-10-31
description: Full repo audit 2026-10-31 — plan approved-scoped, ExitPlanMode DENIED, self-contained EXECUTOR HANDOFF delivered in chat (batches A/B/C/E/F/G/H, Batch D SKIPPED by user); NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_181225f0-17b3-4856-8a75-12d912cd6352
---

Audit 2026-10-31 via two Explore agents + spot-verified top claims (opencode.yml trigger, docker.nix, secret_key monitoring.nix:243, NFS export — all confirmed first-hand). Plan assembled with user answers via AskUserQuestion, **ExitPlanMode DENIED — NOTHING executed**. User then requested a self-contained executor handoff in chat → **HANDOFF DELIVERED** (batches A/B/C/E/F/G/H, verbatim commands + mechanical verification per step + halt rules + report-back format). Outcome of the executor run unverified — check git status next session.

**User decisions (binding):** backups SKIPPED (backlog); image tags KEEP `:latest` (digest-compare refresh instead — consistent with [[jellyfin-pin-nix-media]]); LiteLLM KEEP direct 0.0.0.0:4001 tailnet-only; scope = EVERYTHING incl. P3 polish; **Batch D SKIPPED on request**.

**Batch D = open defects on record (verified, deliberately untouched):** `modules/roles/media.nix:42` NFS export `*(rw,async,…)` wildcard (firewall-only ACL; async = crash-corruption window); `hosts/nix-media/monitoring.nix:243` Grafana `secret_key = "SW2YcwTIb9zpOOhoPsMm"` = Grafana DOCS SAMPLE value. Fix recipes were fully drafted (sops side file `nix-media-monitoring.yaml`, 100.64.0.0/10 export) — revive from this note.

**Other verified findings feeding the handoff:**
- P1: `.github/workflows/opencode.yml` — ANY GitHub user triggers `/oc` agent on PUBLIC repo (body-only check, no author_association gate); `anomalyco/opencode/github@latest` mutable + OPENCODE_API_KEY + id-token:write. Fix: OWNER gate + SHA pin (`git ls-remote --tags --refs` gives peeled SHAs).
- nix-media P2: no docker log-opts/live-restore; containers not RequiresMountsFor-gated on /mnt/storage (nofail disks → dockerd auto-creates empty bind dirs); render=303/video=26 GIDs unpinned; image-refresh restarts ALL unconditionally Sun 03:00; ZERO backups repo-wide; sops nix-media.yaml on retired admin key (user-run updatekeys, SOPS_RUNBOOK §3).
- P3s: single-threaded bridge HTTPServer; port 9095 dup; no per-disk/failed-unit alerts; GC 60d; root ext4 no noatime; mnamer ignores restate defaults; no hardening on custom root units; flake.nix yoga argset dup; update-safe `--pin lucid` not rejected; ci.yml builds both yoga attrs every run; dead `or false` ×5; unfirable hasAttr assertions ×2; power-tlp untyped attrs; REPO_OVERVIEW.md:362 initrd-allowlist rot.
- CLEAN: all options typed, sops wiring, no plaintext secrets tracked, autoUpgrade pipeline, litellm hardening, QSV N100, roles.media.ports single-sourcing, 0.0.0.0:8096 documented exception.

**Handoff key mechanics (for verifying the executor's report):** flake reads git index → git add BEFORE every eval/dry-build (also for edited tracked files); behavior-proofs = `nix eval …system.build.toplevel.drvPath` cmp before/after (Batch B dedup, C4 mnamer extraIgnore must be byte-identical); GID pre-check `ssh nix-media getent group video render` (expect 26/303, else HALT; ssh may stall silently → USER-RUN per [[nix-media-tailscale-ssh-access]]); digest-compare refresh script uses `docker top jellyfin | grep ffmpeg` guard, no `${}` braces in `''` strings; intel-gpu-metrics stays root (unprivileged intel_gpu_top unverifiable without boot — only hardening, no PrivateDevices); docker network NOT renamed. Final gates: nix fmt explicit → flake check (retry on lock race) → dry-build ×3 hosts → VM tests host-units-smoke + nix-media-upgrade-pipeline → NO commits. Report-back = outputs only, pasted into chat for verification.

**Gotcha hit:** first parallel Explore agent spawn failed with "interrupted during streaming recovery" — retried same calls, worked.
