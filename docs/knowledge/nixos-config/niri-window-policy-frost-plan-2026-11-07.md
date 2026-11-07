---
name: niri-window-policy-frost-plan-2026-11-07
description: SUPERSEDED (executed same day as round 4 of niri-rice-polish-2026-11-07)
  — global open-maximized policy + kitty exception + frost diagnosis tree;
  wiki-verified niri maximize/gap facts
metadata:
  node_type: memory
  type: project
  originSessionId: session_2024d12d583ffeb3dad4be9b65769cd4
---

User reported (round 4, 2026-11-07 after [[niri-rice-polish-2026-11-07]]): focused kitty
STILL opaque / only unfocused frosted; zcode opens edge-to-edge, firefox half screen;
GOAL every window opens maximized-but-with-gaps; terminals half-width default with a
maximize toggle (fullscreen only as fallback if impossible — it isn't).

First ExitPlanMode was DENIED with the user note "past fullscreen zcode etc. were
genuinely edge to edge (except top bar)" → the deny line (`open-maximized-to-edges
false`) must STAY next to `open-maximized true`; re-presented plan APPROVED and
EXECUTED the same day — execution record + frost branch outcome (A/B, no frost code
change) live in [[niri-rice-polish-2026-11-07]] round 4.

**Most likely frost cause:** round 3's client-driven fix (kitty `background_blur 1`) is
in the working tree but was NEVER switched + kitty never restarted — plan mode blocked
live-state probes (Bash outside workspace denied), so step 0 of the plan = readlink
~/.config/niri/config.kdl + kitty.conf + pgrep ages, branch: A live still has kitty
blur rule (= round 2, known bug, just switch) / B rule gone but kitty process old
(single-instance trap, 3rd occurrence) / C round-3 provably live + still broken →
fallback lever = re-add `window-rule match app-id=r#"^kitty$"# background-effect { blur
true; xray true }` (xray = efficient non-experimental path).

**Window-open plan:** replace the global deny rule
(`open-maximized-to-edges false` + default-column-width 0.5 in window-rule, lines
~119-133 home/niri.nix) with matchless `window-rule { open-maximized true }` + later
kitty rule `open-maximized false` (kitty then takes layout default 0.5). New bind
`Mod+Shift+F { maximize-column; }` (free; niri's own default puts it on Mod+F, ours is
fullscreen). Layout gaps 12 / default-column-width 0.5 unchanged.

**Wiki-verified niri facts (github.com/niri-wm/niri/wiki):**
- `open-maximized` = "make the window open as a maximized column"; wiki's own example
  is a bare matchless rule for all windows. `open-maximized-to-edges` (since 25.11) =
  like desktop maximize: covers struts/gaps, no borders.
- "Maximized columns still leave space for struts and gaps, and can contain multiple
  windows" → maximized column = exactly "fullscreen but not edge to edge".
- Rules process in order; later rules override earlier fields (can set false, cannot
  unset). `is-floating` match applies only after open.
- `maximize-column` action ≡ set-column-width "100%"; also `maximize-window-to-edges`
  (default Mod+M), `fullscreen-window` (default Mod+Shift+F).
- Non-xray blur "experimental, known limitations", fails during open/close animations;
  xray blur = "the efficient" path. Pop-up blur needs rectangle-shaped geometry.
- wiki.niri.land.org DNS fails here; GitHub wiki works.

**ZCode edge-to-edge root cause:** it never requests xdg-maximize — Electron restores
its own saved full-screen NORMAL bounds, which the deny rule can't touch. Whether
`open-maximized` beats that client geometry at map is NOT documented (wiki silent) —
smoke-test watch-item; fallback = spawn-then-`niri msg action maximize-column` wrapper.

Watch-item: dialogs/floats matching the matchless rule — if any opens maximized, add
`open-maximized false` to its rule.

QC per plan: nix fmt file-args, git add (index), build yoga-niri home-files (runs the
validate gate) + grep generated KDL, `test-suite fast` 4 hosts; VM battery skip. Apply:
`nus yoga-niri switch` → close ALL kitty → smoke (frost both states, maximized-with-gaps
zcode/firefox, kitty half + Mod+Shift+F toggle).
