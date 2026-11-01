---
name: lucid-smoothcaret-plan-2026-10-10
description: Smooth-caret saga CLOSED 2026-10-12 — five designs EXECUTED+tested over
  two nights, all dead live; patch 120 REVERTED per protocol (layer back to 11
  patches incl. 121-v2); complete Qt-source-verified post-mortem + the one
  untried avenue (Timer-polling) archived in runbook + this file
metadata:
  node_type: memory
  type: project
  originSessionId: sess_3e6d70ea-13f8-4611-bf92-890851b9c4e4
---

**2026-10-12 — REVERTED, saga CLOSED.** v5 was genuinely live (shell hot-reloaded the v5 tree at 00:39:42, "Configuration Loaded") and its `caret glide` instrumentation fired **zero** lines during the user's test → even a plain in-file child with STATIC-id `cursorRectangle` bindings receives no movement notifications in quickshell's live pipeline. That falsified the last QML-carried mechanism class; patch 120 removed per the pre-recorded protocol with user agreement. Revert QC: real-build 0/zero-fuzz, absence checks green (no glideCaret / no patch-120 markers in built source, upstream LockField caret restored, SmoothCaret absent), attribution diff **0 lines** vs the current 120-free layer (note: first diff showed 102 lines in PasswordEcho.qml = parallel session's 121 v1→v2 evolution, resolved by rebuilding prev with current patches), flake check + dry-build 0. STAGED, never committed. Layer = 11 patches (001,104,111,113–119,121-v2). Runbook carries the post-mortem in the dropped-patches notes; lucid.nix 120 entry fully removed. USER: next switch + `systemctl --user restart lucid` restores the stock blinking caret.

**If EVER revisited (explicitly rejected for now — no sixth round):** the only untried mechanism is a Timer polling `input.cursorRectangle.x/y` every ~16–33ms and writing the follower's slot properties through the QML path — notification-independent by construction, immune to both verified failure modes; costs a permanent poll per field. Everything else (delegates in any binding form, cross-component followers, FrameAnimation) is empirically dead — see the five-design archive below.

**If the user reports STILL no glide after switch+restart:** the static-id mechanism class is then falsified too — canary test upstream lucid's own LockField caret (same delegate mechanism, unpatched behavior), and check whether `cursorVisible`-bound visibility flips while x stays (would mean delegate bindings update but Behaviors don't → last resort = FrameAnimation INSIDE the static-id delegate). Confidence high: identical binding class to lucid's 153 live Behaviors.

**v3 A/B OUTCOME (resolved 2026-10-11 ~23:00):** live log showed the middle branch — 21× "smoothcaret attached" (incl. 12 at once when a many-input surface opened) but ZERO "smoothcaret jump" lines and zero binding errors → components instantiated, position bindings frozen → led to the dynamic-lookup root cause above. v3 harness had passed offscreen (FrameAnimation lerp 62, live-component 52) — again interpreted-vs-compiled.

Offscreen proofs (qtdeclarative from nixpkgs, QT_QPA_PLATFORM=offscreen, exit codes): FrameAnimation lerp PASS 62 (≥4 intermediates); v3 live-component (Theme-stubbed /tmp/SmoothCaret.qml beside test root) PASS 52. Gotchas this round: duplicate `Component.onCompleted` on one object is invalid — merge handlers; `onChildChanged` doesn't exist on Rectangle (silent load failure = "Did not load any objects", exit 2); /tmp/lucid-update-dk AND /tmp/qtd got cleaned between sessions — /tmp trees are ephemeral, reconstruct via upstream clone + 001–119 + apply current 120 patch.

**v3 A/B OUTCOME (resolved 2026-10-11 ~23:00):** live log showed the middle branch — 21× "smoothcaret attached" (incl. 12 at once when a many-input surface opened) but ZERO "smoothcaret jump" lines and zero binding errors → components instantiated, position bindings frozen → led to the dynamic-lookup root cause above. v3 harness had passed offscreen (FrameAnimation lerp 62, live-component 52) — again interpreted-vs-compiled. QC this round all green (real-build 0/zero-fuzz, markers ×8, attribution 0 lines, qmllint 0, flake+dry 0), STAGED.

**Switch-timeline facts (2026-10-11 ~20:57):** v2 + parallel quickshell 0.3.2 deployed together (see [[manual-pkg-updates-2026-10-10]]); mid-rsync the running instance hit transient reload failures (`Privacy is not a type`, `Qt5Compat.GraphicalEffects not installed`) — half-synced-tree artifacts, gone after restart; expect on every lucid switch.

**QSG_INFO question CLOSED** (env removed): `threaded render loop`, `Animation Driver: using vsync: 8.33 ms` = true 120Hz animation clock; driver flips timer↔vsync mode with window count, always 8.33ms. Launcher selection already glides (LauncherList.qml ~232, 180ms OutCubic + proximity tint) — no other identified snap-point.

Test-tooling lore: qml harness = exit-code protocol (42/52 pass; negative control 45); two root objects in one file = exit 2; Write tool does NOT expand $USER; qmllint from qtdeclarative (/tmp/qtd) catches what the nix patch build cannot.
