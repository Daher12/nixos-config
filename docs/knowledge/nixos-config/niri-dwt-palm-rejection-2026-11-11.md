---
name: niri-dwt-palm-rejection-2026-11-11
description: yoga palm rejection regression on niri = dwt omitted; niri 26.04
  omission forces DWT OFF (not libinput default); bare `dwt` fix EXECUTED+QC
  green STAGED 2026-11-11, user switch pending
metadata:
  node_type: memory
  type: project
  originSessionId: session_fa680096165c6e796f8999da773a5523
---

User reported palm rejection broken "lately" on yoga-niri (symptom: while typing). PLAN was denied 2026-11-11, then user said "execute" same day: **EXECUTED + `test-suite fast yoga-niri` green, STAGED — user runs `sudo nixos-rebuild switch --flake .#yoga-niri` (still pending).** Fix applied = bare `dwt` flag in touchpad block at home/niri.nix (kept `tap` + `natural-scroll`), trap comment included. Proof chain: `niri-config.kdl.drv` rebuilt (runs `niri validate`), and `nix build .#nixosConfigurations.yoga-niri.config.home-manager.users.dk.home-files` + grep shows `dwt` in the generated `.config/niri/config.kdl`.

**Root cause (proven against installed niri v26.04 source):**
- `niri-config/src/input.rs`: `tap`/`dwt`/`dwtp` are `#[knuffel(child)] bool` presence flags — absent line = **false**, and plain bool flags do NOT accept arguments (only `drag` is `Option<bool>` + `unwrap(argument)` → `drag false` works, `tap false` does NOT; disable = omit).
- `src/input/mod.rs` `apply_libinput_settings`: calls `config_tap_set_enabled(c.tap)` / `config_dwt_set_enabled(c.dwt)` **unconditionally** → omission ACTIVELY disables libinput DWT (which is enabled-by-default otherwise). Same unconditional pattern → any niri touchpad setting you don't write is forced off, not left at libinput default.
- Hyprland (`home/hyprland.nix:236-245`, only natural_scroll set) defaults DWT ON → typing suppression silently vanished in the niri switch. Core palm detection (pressure/edge zones) is libinput-internal, always-on, unchanged — same libinput 1.31.3 + kernel 7.2.11 on both attrs.

**Lore:**
- Web-search/wiki claims about niri defaults are UNRELIABLE (claimed "dwt defaults to true" — wrong for 26.04; default-config.kdl comments are "examples, not defaults"). Verify at the exact tag: config lives in `niri-config/` crate (not src/config.rs); apply logic in `src/input/mod.rs`; repo = niri-wm/niri, tags like v26.04.
- User unsure whether tap-to-click existed pre-switch — follow-up lever if resting-palm clicks persist: drop `tap`.
- DWT timeout not tunable in niri 26.04 (boolean only; libinput 1.31 added timeout API niri hasn't exposed). `toggle-touchpad` action merged upstream Oct 2026, NOT in 26.04.
- Hardware: ELAN06FA:00 04F3:3202 I2C touchpad + AT Translated keyboard, no touchscreen; Hyprland-era tap default ON (conf format) per community sources.
- Validation probe: `printf '...' > /tmp/x.kdl && niri validate -c /tmp/x.kdl` — plan mode blocks writes, run in exec mode.
- Hyprland wiki moved to wiki.hypr.land (old URLs 301→404).

Related: [[niri-testing-trial-2026-11-05]], [[shell-strategy-converge-niri-noctalia-2026-11-07]]
