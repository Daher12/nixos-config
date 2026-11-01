---
name: lucid-integration-evaluation-2026-10-13
description: Full lucid integration evaluation 2026-10-13 — verdict KEEP
  architecture; German cluster = the one inefficient part; runbook staleness fix
  planned, execution handed to glm flash
metadata:
  node_type: memory
  type: project
  originSessionId: sess_210cce3f-3961-482d-a65b-33f347f5373b
---

Evaluation of the whole lucid integration, 2026-10-13 (3 parallel Explore agents + upstream research). Verdict delivered to user.

**Verdict: architecture is optimal for this software — keep.** Every alternative loses for cause: flake=false source pin (lucid packaged NOWHERE — nixpkgs 404, FlakeHub negative, upstream = Arch install.sh only); build-time patches beat seds (migrated 09-28); rsync deployment forced by lucid's state-in-own-tree design (gated by upstream install.sh exclude-list); own fork already rejected (same conflicts, worse auditability — confirmed again); nixpkgs quickshell loses (26.05=0.3.0 below floor, and patch 201 forces local C++ rebuild anyway → no cache benefit). Most fragile nix piece = quickshell wrapper replication (must be re-compared vs upstream default.nix per bump; exists because withModules discards prior overrideAttrs).

**The one real inefficiency: German i18n cluster** — 7 of 11 patches, ~2,253 of 2,613 lines; upstream has NO i18n framework, nothing in flight, releases ~weekly (v0.57 Aug 29 → v1.20 Oct 8); string-literal patches are maximally conflict-prone; can trip the runbook's ">half reject → STOP" alone. Escape hatches ranked: (1) upstream an i18n mechanism (kills the class, high effort), (2) upstream small general patches, (3) status quo.

**Upstream PR candidates** (would shrink layer / retire fragile plumbing): 001 as respect-$XDG_DATA_DIRS (deletes patch), 111 hidpi sourceSize (bugfix), **201 to quickshell — all 4 cited issues #1007/#1028/#1056/#1079 STILL OPEN, no PRs; merging it would retire the wrapper replication entirely**, 104/116/121 as v1.20 settings toggles.

**State facts (2026-10-13):** pins AT upstream HEAD — lucid e662954 = v1.20 tag = main HEAD; quickshell 4f508be = 0.3.2 release commit = master HEAD (both Oct 8, zero commits since); nixpkgs unstable quickshell = 0.3.2, 26.05 = 0.3.0; dank-greeter alive (commits Oct 12, no tag past v1.6.2 which pin contains). Natural rest point.

**Runbook staleness found (verified):** LUCID_RUNBOOK.md line ~76 "exactly TWELVE patches" (actual 11), gates table ~128 + Appendix B ~515 say 0.3.1 floor (actual "0.3.2" at lucid.nix:201), Appendix B ~514 "12 patches", ~515 quickshell rev 5d5d498/0.3.1/2026-10-03 stale (actual 4f508be/0.3.2/2026-10-08).

**Fix plan approved by user ("plan approved let me switch to glm flash for execution")** — 4 exact edits + grep sweep + git add, no commit; NOT executed by this session (first ExitPlanMode un-answered, second denied — user is running it with glm flash). Related: [[plans-for-weaker-executor]], [[lucid-runbook-2026-10-08]], [[quickshell-icon-race-fix-2026-10-10]].
