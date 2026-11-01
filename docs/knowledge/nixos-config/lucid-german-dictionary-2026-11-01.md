---
name: lucid-german-dictionary-2026-11-01
description: EXECUTED+QC green STAGED — German patches 113-119 replaced by
  en-de.json line rules + translate.py (byte-proof 0-diff), 131 residual, 129
  re-based, stable-tags-only bump policy, 001 upstream PR drafted, PR1049 plan
  abandoned; pending switch
metadata:
  node_type: memory
  type: project
  originSessionId: session_a8403f5c3853d9d7814d3261856b070e
---

2026-11-01 lucid patch-layer maintenance reduction — EXECUTED, QC green, STAGED (no commit).

**German dictionary switch:** patches 113/114/115/117/118/119 (~2,280 lines = 73% of the layer) deleted; replaced by `home/lucid-german/en-de.json` (318 exact line rules across 33 QML files) applied at build time by `home/lucid-german/translate.py` in `lucidPatched`'s postPatch (nativeBuildInputs += python3). Zero-match rule = build failure naming file+line (the .rej equivalent). Rules map FULL lines → full German lines verbatim, including the `// nixos-config local patch 113 (German)`-style markers (41 of them, Appendix A sentinel ≥40).

**131-german-residual.patch** = the 5 non-literal hunks (LockMedia marker-comment + title line, System.qml `Qt.locale("de_DE")` date, ClockToday tile expressions, Chrono pomodoro announce, SessionMenu uptime). Numbering skips 130 deliberately ([[lucid-brightness-steps-plan-2026-11-01]] earmarks it). **129 re-expressed against ENGLISH context** (old hunks sat on 114's German WifiPanel text; German fallback strings baked in its + lines, translator never sees English there).

**Byte-proof:** built `lucid-source` store output diffed 0 (full tree, wallpapers included) against the 19-patch reference `/nix/store/pivg6309…-lucid-source-1.20.5.5-local`; after the separate 124 `// //`→`//` comment fix the delta is exactly 2 comment lines (`pg1a2n4lq0w…`). Method that worked: scratch candidate loop (upstream + kept patches + 129-new + 131 + translator vs reference) BEFORE the nix build; the loop caught a real bug (LockMedia port dropped the German title line — would have broken lockscreen media).

**Bump policy (user decision):** stable tags only, opportunistic, never chase betas; pin STAYS on beta 1.20.5.5 @ 2945eab — no downgrade. Watch: upstream PR #97 obsoletes 104, PR #98 obsoletes 123 (drop via P3 when merged). **PR1049 disk-cache plan ABANDONED** (runbook Appendix B + §1).

**001 upstream PR draft** at `docs/upstream-prs/001-xdg-data-dirs/` (XDG_DATA_DIRS patch vs 2945eab + PR-BODY; shell expansion + resolve-icons functionally tested, applies clean). Local 001 stays until merged+tagged. User submits.

**Pending:** user switch + `systemctl --user restart lucid` + P7 smoke (output byte-identical → no visual change expected).

**Lore:** lucid upstream source is 754M (738M wallpapers) — /tmp's 2GB tmpfs cannot hold scratch trees, use home disk; a cp killed by ENOSPC leaves store perms (dirs 555) that make `rm -rf` fail with EPERM ("Keine Berechtigung") — `chmod -R u+w` first. Reference store paths survive in /nix/store long after; extract from the activate script (`grep -o '…-lucid-source-…' $ACT/activate`).
