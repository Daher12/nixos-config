---
name: repo-audit-followup-plan-2026-11-15
description: SUPERSEDED (executed same day, see audit-fixes-2026-11-15) —
  audit facts + user decisions remain valid; ExitPlanMode denial was followed
  by manual plan-mode exit + "execute plan"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_432505d6-947f-4168-bdb5-db72b9e8e692
---

Full-expert repo audit 2026-11-15 (main @ 555ba56) via 3 parallel Explore agents + spot-checks. **Verdict: fleet unusually healthy** — all three hosts optimized for use cases; zero dead modules; zero functional hyprland remnants (only stale comments/docs); every flake input used; sshd never re-weakened. yoga on live gen 202 (repo ahead of machine until `nus yoga switch`).

**User decisions via AskUserQuestion:**
- Selected: P1 doc/comment rot + P1 persistence (`.local/state/zcode`, `.local/share/onlyoffice`) + P2 dedup/posture
- **Grafana `secret_key` sops move SKIPPED** (stays hardcoded, monitoring.nix:269 — known, documented)
- **sudo timeout 30 → 15 min** (modules/core/users.nix default)

**Approved plan (NOT executed — ExitPlanMode denied):**
- Docs: REPO_OVERVIEW :279 noctalia v5.4.1→v5.5.0, :281 drop stale spotx revs, :426 docker_29 pin claim wrong (no pin in docker.nix), :500 idle paragraph still points at lucid prefs.json; README:205 "every host" (yoga-gnome weekly-only); AGENTS.md :23 add nix-media-silo.yaml, :80 opencode-wrap example → home/opencode.nix; stale hypr comments in home/niri.nix:41,47,279,293 + browsers.nix:107 ("Hyprland autologin" → greetd)
- Dedup: new `modules/features/swapfile.nix` (enable/sizeMiB/device, replaces identical blocks yoga:265 + latitude:140); new `lib/keys.nix` fleetKeys via mkHost specialArgs (dedupes dk@yoga pubkey in latitude:51 + nix-media:45); journald fleet default `mkDefault "SystemMaxUse=200M"` in core/systemd.nix (yoga line deleted, latitude 100M + nix-media block override by priority); new `core.nix.trustedUsers` option, nix-media narrowed to `["root"]`
- Proofs required: before/after `nix eval` of swapDevices / authorizedKeys / journald.extraConfig / trusted-users; `git add` new files pre-eval; test-suite fast; VM battery recommend skip

**Audit facts worth keeping (not plan items):** preload-ng pin ~10mo = upstream dormancy (in weekly update list); safe-input list duplicated update-safe ↔ bump.yml; VM-test gaps = silo never starts, caddy/monitoring/niri-session/greeter untested; update-safe commits lock BEFORE activation; install.sh creates English XDG dirs vs German fleet; weekly-reboot load guard truncates 2.x→2; latitude open items = SecureBoot sbctl verify + sops re-encryption (SOPS_RUNBOOK §3); zen kernel on Broadwell = least-fitting but deliberate profile default; `api.key` at repo root (gitignored).

Related: [[cleanup-round-2026-10-24]], [[audit-fix-round-2026-10-31]], [[fleet-automation-review-exec-2026-10-19]]
