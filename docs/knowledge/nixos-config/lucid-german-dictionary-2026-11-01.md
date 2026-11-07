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

**Dedicated no-VM QC round (later same day): PASS.** (1) Rebuild from current index reproduces identical store paths (`cr1yx0v8…` generation / `pg1a2n4lq0w…` lucid-source); both eval gates render ok; `nix flake check` rc=0. (2) Independent roundtrip from STAGED git blobs (14 patches + dict + script via `git show :path`) onto a fresh full 754M upstream copy → 0 diffs vs the nix-built output; all patches apply with zero fuzz/offset. (3) Negative gate test: mutate one dict-keyed EN line → translator exits 1 naming `Zones.qml: no match for: return "Same time";` — loud gate proven live. (4) Appendix A marker battery 52/54; both fails were in my expectations — one harness error (`=` vs runbook's `≥1`; envtool.py carries 2 markers because 001 edits 2 lines), one REAL doc defect fixed: my new dict-sentinel row claimed `ausstehend`=1 but artifact correctly has 2 (DND + quiet-hours lines, old 117 row knew) — runbook fixed + re-staged. (5) Dict integrity exact: 33 files/318 rules, 0 dup keys, 0 no-op rules, no umlauts in keys (keys = pre-translation English lines); fmt idempotent; secrets clean; PR draft re-applies to pristine upstream. Net layer delta −1,602 lines (766+/2368−).

**translate.py known quirk (left as-is):** NOT idempotent — a second run on an already-translated tree reports every rule unmatched (German replaced the English keys; it also writes files before failing, so the negative-test run pre-translated the tree — cosmetic, build path runs once on a fresh derivation and a failed postPatch discards everything). If ever hardened (treat already-German line as hit), re-run the byte-proof after.

**Lore:** lucid upstream source is 754M (738M wallpapers) — /tmp's 2GB tmpfs cannot hold scratch trees, use home disk; a cp killed by ENOSPC leaves store perms (dirs 555) that make `rm -rf` fail with EPERM ("Keine Berechtigung") — `chmod -R u+w` first. Reference store paths survive in /nix/store long after; extract from the activate script (`grep -o '…-lucid-source-…' $ACT/activate`).
