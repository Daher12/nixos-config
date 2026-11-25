---
name: user-communication-style
description: User asks for plain-language restatements when answers get dense
  and scrutinizes any autonomous machine behavior (auto-reboot, scheduled
  wakeups) — lead with the simple bottom line and state automatic-action
  triggers up front
metadata:
  node_type: memory
  type: user
  originSessionId: sess_cc7b19eb-deb6-4e4a-82db-5de5dd509ecb
---

David (nixos-config) engages deeply with system internals but will explicitly ask to "explain that in simpler terms" after dense multi-paragraph technical answers — so lead with a one-sentence plain-language answer, then layer the detail.

**Why:** two consecutive follow-ups in the 2026-09-09 yoga-s2h discussion were simplification requests and a startled "it will automatically reboot? without me looking?" — the dense answer had buried the actionable behavior.

**How to apply:** when describing any automatic/autonomous machine behavior (reboots, wakeups, scheduled tasks, self-modifying hooks), state its exact trigger conditions and safety interlocks up front and plainly — don't leave them as asides inside a longer narrative. Prefer analogies over jargon when the concept is kernel/systemd-internal.

**Handing off user-executed steps (2026-11-25 perf round):** after approving a plan, David asked to "explain my todos in easy terms and in steps with copyable commands, also explain the expected end goal" — structure handoffs as numbered steps, each with a one-line "what this measures/does", exact copyable commands (define a session alias for long command lines), an explicit before/after comparison instruction, and a short before-vs-after end-goal table. AskUserQuestion with a clear "(Recommended)" option worked well that same day (priorities/experiments scoping + VM-gate skip decision) — earlier "prefers free-form over AskUserQuestion" ([[yoga-hibernate-status]] era) has softened; recommend-with-options is fine, plain free-form text questions still fine for open-ended input.

David also runs explicit post-execution review turns (e.g. "verify this was the appropriate and most efficient way to handle this issue", 2026-10-10) — after nontrivial execution, expect an audit request and answer it with evidence (hashes, byte-diffs, gate outputs, rejected-alternatives reasoning), not reassurance. Keep verification artifacts quotable while executing.
