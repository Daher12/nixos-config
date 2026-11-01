---
name: lucid-lock-dots-fadein-2026-10-11
description: Patch 121-plain-dots v2 (lock/polkit password dots → PRE-v1.20
  caret-line→dot morph) EXECUTED 2026-10-12 after user live-tested v1 fade and
  preferred the old animation; all QC gates green, STAGED; relay pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_25e7c00c-a00e-4f4d-bf7e-5bd034a5062d
---

User disliked the v1.20 "Lucid 2" password-beads animation (`lucidui/PasswordEcho.qml`; upstream commits f4992a6 + 0640c89). Old = v1.1–v1.10.x caret-line→dot 300ms morph.

**v1 (2026-10-11):** simple fade-in — EXECUTED, gates green, user switched + tested live.

**v2 (2026-10-12): user preferred the pre-v1.20 animation over the fade** — reworked 121 IN PLACE (still only file: `lucidui/PasswordEcho.qml`, after 120 in `home/lucid.nix`): new `born` scalar on the delegate; the tessellated Shape/PathSvg REPLACED by a morphing Rectangle (born=0: `Theme.dp(2)` wide × `2·echo.dot` tall, 45% opacity pill, radius width/2; born=1: `echo.dot` dot; scale keeps gone/shown/bob/pick terms, opacity gets `(0.45+0.55·born)`); `life` = Pause(lag) → ScriptAction snaps pop/grow/settle/melt/lit=1 → born→1 over `Theme.ms(300)` `easeEmphasizedDecel` (verbatim old params). PathSvg/Shape import now unused (harmless); `"shape": "circle"` kept (role unused, self-documenting). Death fade, reveal, selection band, busy ripple, paste cascade stay upstream. Appendix A expects: marker 2, `property real born` 1, PathSvg 0, easeEmphasizedDecel 2. Runbook §1 row + lucid.nix comment updated to v2.

**Gates all green:** real build (121 applied, no fuzz, both eval gates), content gate, attribution (PasswordEcho section = exactly 121's 4 hunks; 48 files total now — caret v5 dropped SmoothCaret.qml), **byte-identical cumulative exit 0**, flake check + dry-build 0. STAGED not committed.

⚠️ **Gotcha that nearly shipped a broken patch:** a PARALLEL session (glass-frost round, see [[parallel-index-work]]) re-materialized /tmp/lucid-update-dk — `prev`/`work` were upstream+001-121(fade), NOT the 11-patch baseline. `diff prev work` produced a fade→morph delta that would have REJECTED on the real baseline. Caught it by reviewing hunk `-` sides (fade text on the minus side = wrong baseline). Fix: since no other patch touches the file, diff `upstream/<file>` vs `work/<file>`. RULE: always verify the `-` side of a regenerated patch shows UPSTREAM content, and dry-run against a freshly built baseline tree, not a reused prev. User relay pending: switch → `systemctl --user restart lucid` → lock+type.
