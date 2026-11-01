---
name: lucid-runbook-2026-10-08
description: LUCID_RUNBOOK.md authored (root, tracked) — LLM-executor runbook
  for lucid pin bumps + patch triage; marker table verified against live store
  tree; documentation/ is gitignored (drove the root location)
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e5c6aa19-c810-4228-b11c-08d779edad75
---

2026-10-08: planned (approved) + executed the lucid update/triage runbook for a
lesser AI executor.

**Deliverable:** `LUCID_RUNBOOK.md` at repo ROOT (tracked, SOPS_RUNBOOK.md
precedent), ~480 lines, LLM-oriented: §0 hard rules, §1 anatomy + 13-patch
inventory + gates table + "dry-build does NOT apply patches" asymmetry, §2
planned lucid bump P0–P7 (real-build gate = activationPackage with -L; per-patch
triage loop with prev/work snapshots in /tmp; eval-gate remedies; content gate;
QC chain; user smoke-test relay keyed per patch), §3 quickshell/dank-greeter
pairing (floor raise only AFTER smoke test), §4 unplanned drift, §5 symptom→fix
playbook (build/activation/runtime), §6 rollback, §7 stop conditions + report
format, Appendix A marker greps, Appendix B pins.

**Location flip (plan said documentation/, executed root):** `documentation/`
is deliberately GITIGNORED (".gitignore: # Local documentation (kept locally,
not pushed)") — discovered when git add refused. A tracked-pointer from
AGENTS.md/REPO_OVERVIEW.md into an ignored dir would dangle on every clone
(AGENTS.md lesson 1). INDEX.md still updated (local catalog; row under Related
Root-Level Files with ../LUCID_RUNBOOK.md + cross-ref entries) — INDEX itself
is local-only.

**Key correction baked into the doc AND REPO_OVERVIEW §381:** the old regen
recipe "diff fresh upstream vs deployed tree" is only valid when the pin did
NOT move; on a real bump it folds upstream's changes into "our" patches. §381
lead-in retitled "Regenerating the patch layer" + appended distinction +
pointer to the runbook's per-patch triage.

**Verification (all green):** full 17-grep Appendix A suite executed against
the real built tree `/nix/store/dmrbih9x…-lucid-source-1.10.5-local` (the
001–110 build; 2 rows corrected during QC — the 107 markers live in
`lucidlock/LockNotifs.qml` and `Lockscreen.qml`, NOT Notifications/Bluetooth
panels); activation gate comments exist verbatim in the real generation
(`# stateFiles cross-check vs upstream install.sh: ok`, `# quickshell engine
floor: ok` — greppable proof, used as P2 pass criterion); the SRC-extraction
grep and `nix flake metadata --json | jq '.locks.nodes…'` both tested working;
`nix flake check` exit 0.

**Patch-layer facts re-confirmed:** 107–110 headers use `base/`+`b2/` (108:
`b2/`+`c2/`) prefixes — `patch -p1` strips one component either way; 003/106
order-coupled (106 deletes 003's line — joint marker `shown: Prefs.showMedia
&& root.player !== null`); 105 verified by ABSENCE (Spielmodus/"Energie" = 0);
001 carries literal `# nixos-config local patch` inline tags = natural marker;
eight lucid-source store copies exist — discriminate by newest-patch markers,
not mtime (all Jan 1 1970).

**State:** STAGED (A LUCID_RUNBOOK.md, M AGENTS.md, M REPO_OVERVIEW.md) +
local INDEX.md; NOT committed (house rule). AGENTS.md now routes
lucid-patch-breakage to the runbook.

**2026-10-09 follow-up:** v1.20 "Lucid 2" bump plan approved + handed to
executor ([[lucid-v120-update-plan-2026-10-09]]) — when executed, the runbook's
§1 13-patch inventory shrinks to 001 only (12 patches dropped, git history
preserves them) and Appendix A/B + anatomy + "Last verified" need the
same-change update (plan P6). Patches 103–110 since COMMITTED (6050cf8).

Related: [[lucid-buildtime-patches-2026-09-28]],
[[lucid-lock-beads-layoutchip-2026-10-08]], [[plans-for-weaker-executor]]
