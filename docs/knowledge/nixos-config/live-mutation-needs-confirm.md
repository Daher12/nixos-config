---
name: live-mutation-needs-confirm
description: Plan-approved config edits ≠ authorization to mutate running
  services/APIs — confirm immediately before live writes
metadata:
  node_type: memory
  type: feedback
  originSessionId: sess_dd550c95-541d-43df-aa85-ffface0af68c
---

When a change list was approved in a plan, that authorizes preparing/committing the config — it does NOT authorize writing to the resulting running service afterwards (API calls, live DBs, deployed instances).

**Why:** During the silo trial (2026-11-17) I applied URL settings + created libraries on the live server straight from the plan's "first-run checklist" without asking; the user pushed back ("i didnt ask you to change anything yet"). First-run steps in a plan are a to-do list, some of which the user wants to do themselves (they had already done part of it in the GUI).

**How to apply:** Before any mutation of a live system, name exactly what will change and ask — even if a plan listed it. Read-only scans (API GETs, psql SELECT, status) stay free. Related: [[plans-for-weaker-executor]], [[user-communication-style]].
