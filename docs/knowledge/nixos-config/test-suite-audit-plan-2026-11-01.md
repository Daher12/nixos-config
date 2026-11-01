---
name: test-suite-audit-plan-2026-11-01
description: Plan-mode audit of the VM-test suite + shared agent test-suite
  design (ExitPlanMode DENIED, NOTHING executed) — findings incl. ssh-firewall
  drift, README 3-of-7 staleness, no interactive test VM
metadata:
  node_type: memory
  type: project
  originSessionId: sess_a92b779c-0a35-4ddd-836e-b14009ae2acb
---

2026-11-01 plan-mode session: user asked to "verify the test VM is up to par" and make opencode/other agents use the same testing suite as zcode. ExitPlanMode was DENIED — plan delivered in chat, NOTHING executed.

Findings (verified by Explore agents):
- No interactive test VM exists anywhere in the repo (no test-vm host attr, no vmVariant; `lib/mkHost.nix:28-29` comment anticipates one). "The test VM" = the 7 unattended NixOS VM tests in `tests/`, exported at flake.nix:288-326. Last green run 2026-10-19; staged 2026-10-31 sweep modified modules several tests import — unvalidated.
- Drift defect: `ssh-firewall` test restates the nft rule inline (tests/litellm-firewall.nix:55-63) instead of importing modules/core/openssh.nix:44-50.
- README lists only 3 of 7 tests (README.md:140-141, 196-198); REPO_OVERVIEW documents only virbr0-firewall.
- Nobody runs the suite: AGENTS.md § Verification workflow (QC), update-safe, ci.yml/bump.yml all stop at fmt/flake-check/dry-build. AGENTS.md is the single chokepoint read by zcode (agentsMd), opencode (convention + `context = ../AGENTS-global.md` in home/opencode.nix:47), GitHub opencode bot. `.opencode/` dir is untracked local plugin-dev deps (node_modules) — opencode custom commands would go via HM-managed `~/.config/opencode/command/`.

Approved plan (user answers): scope = verify & repair + short eval of interactive test-vm (integrate only if deemed necessary — verdict was NOT: GUI stack untestable in QEMU, naive build-vm breaks on disko/sops/impermanence, update-safe+generations already cover boot safety; future path = unattended boot-smoke test). Wiring = Runner + AGENTS.md only (user explicitly did NOT pick opencode command / CI job / update-safe --vm). Contents: run all 7 tests vs staged tree; de-drift ssh-firewall via `opensshModule` callPackage arg; new `scripts/test-suite` (tiers fast/vm/full, handles bare-`nix fmt` stdin trap + unstaged-.nix warning); AGENTS.md QC rewrite pointing all agents at it; README/REPO_OVERVIEW sync. See [[workflow-simulation-suite-2026-10-19]] for the tests themselves, [[audit-fix-round-2026-10-31]] for the staged tree being validated.
