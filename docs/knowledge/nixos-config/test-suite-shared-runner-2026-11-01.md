---
name: test-suite-shared-runner-2026-11-01
description: EXECUTED+ALL GREEN STAGED — scripts/test-suite shared runner
  (fast/vm/full/suggest + user confirmation gate), ssh-firewall de-drifted to
  real openssh.nix, docs synced; 5-test VM battery passed in ~11 min
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a92b779c-0a35-4ddd-836e-b14009ae2acb
---

Executed 2026-11-01 (supersedes [[test-suite-audit-plan-2026-11-01]], whose ExitPlanMode was denied; user then approved verbally with one addition):

- **scripts/test-suite** (new, staged): `fast [host…]` = flake check + per-host dry-builds (standing gate, no confirmation; defaults yoga latitude nix-media), `vm [name…]` = the 7-test QEMU battery, `full`, `suggest` = changed-files→covering-tests map. The mapping table lives in the script — keep in sync when adding a test (module patterns AND tests/*.nix files themselves).
- **User-ordered confirmation gate** (verbatim ask: agent must evaluate necessity, recommend, then ask full/partial): baked into AGENTS.md § Verification workflow (QC) — steps: run suggest → sanity-check mapping → short evaluation (coverage, runtime, is runtime evidence needed) → recommend full/partial/skip → ASK → run only what was approved. AGENTS.md is the single shared doc, so this binds zcode, opencode and the GitHub bot alike. No opencode-native /test command was added (user chose Runner+AGENTS.md only).
- **ssh-firewall de-drift**: tests/litellm-firewall.nix imports the REAL modules/core/openssh.nix (flake.nix passes `opensshModule`); the inline nft-rule copy is gone — the test now proves the module-generated rule. Passed live (147s).
- **Docs synced**: AGENTS.md (QC rewrite + layout bullets), README (7 tests listed — was stale at 3 — + runner), REPO_OVERVIEW (tree lines, scripts table row, new `### test-suite` section, Common Commands).
- **Interactive test-vm host: evaluated, NOT built.** Reasons: yoga's risk = GUI stack (untestable in QEMU); naive build-vm breaks on disko/sops-ssh-identity/impermanence (host-units-smoke:78-92 hand-suppresses exactly these); update-safe build-before-activate + generations already cover "prove before switch". Future path if needed: one unattended boot-smoke test.
- **Battery outcome** (gate: user didn't answer full/partial → fallback = recommended partial per plans-for-weaker-executor): 5/5 PASS — ssh-firewall 147s, litellm-gateway 233s, virbr0-firewall 146s, nix-media-upgrade-pipeline 4s (cache hit = same derivation already green), host-units-smoke 122s; wall ≈11 min. Fast tier green first. The 2 skipped (zram-heal, yoga-s2h-logic) cover modules unchanged since the 2026-10-19 green run.
- Still uncovered by any VM test (user declined the add-on): nix-media monitoring stack (monitoring.nix + alertmanager-ntfy-bridge.py), caddy, and all HM/desktop layers. CI still does NOT run VM tests (flake check + dry-builds only) — deliberate, kept fast.
- **QC round (user-requested) after the battery**: shellcheck found SC2155 on `readonly REPO=$(…)` → fixed with split assignment + `|| pwd` fallback (also makes `--help` work outside a git tree); flake.nix test comment now points at the runner; error paths verified (invalid tier/host/test → exit 1, help/bare → exit 0); staged-diff review clean; final `test-suite fast` green on the full 35-file combined staged state; staged == worktree for all session files. No battery re-run needed (post-battery edits were bash script + comments only — eval-identical, revalidated by flake check).
