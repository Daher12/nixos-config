# Lucid update & patch triage runbook (for AI agents)

Audience: an AI execution agent working in `/home/dk/nixos-config` on host **yoga**
as user `dk`. You have no sudo, you cannot run `nixos-rebuild switch/test/boot`, and
you cannot see the screen — deployment and visual checks are relayed to the user.
This document is written to be self-contained: every command is verbatim, every
gate has an exact pass criterion, every failure has a table entry. Do not improvise
outside this document; when something is not covered, STOP and report (§7).

Read `AGENTS.md` first for repo-wide rules. This runbook covers only the lucid
patch layer: what happens when the lucid (or quickshell / dank-greeter) flake
input moves, how the build-time patches are validated or repaired, and what to
do when things break at build, activation, or runtime.

Last verified against the repo on 2026-11-01 (lucid @ `2945eabac`, the upstream
**beta 1.20.5.5** — Lumen file manager + Lens picture viewer + LucidShot
rebuild + edit mode, 14 patches + the German line-rule dictionary — the
2026-10-31 bump re-expressed two patches
on upstream's churn: 001 (the appScanner awk gained a 9th output field
`clean(cats)`; the same NixOS dirs + locale-aware `Name[...]` rule + marker
re-applied on the new line) and 111 (upstream's `lucidSlot` feature changed
the two `visible:` lines after the tray icon sites; the same
`backer.sourceSize` insertions re-placed); the stateFiles gate gained
`lucidbar/chrono.json` (Chrono app state, shipped default-less like
icons.json). New-surface wiring this bump: the quickshell wrapper gained
`qt6.qtwebengine` + `qt6.qtimageformats` (Lumen preview pane / image codecs).
**Reverted 2026-11-01**: the wrapper also gained `qt6.qtmultimedia` (upstream
install.sh lists it REQUIRED — `PreviewPane.qml` imports QtMultimedia and the
missing module killed the whole Lumen window on launch), the `lucidSync`
registrar loop (`lumen/lens --default`) was removed, and the `files` keybind
(SUPER+E) migrates Lumen→nautilus while it matches the Lumen default — Lumen
stays launchable from its desktop entry until it proves out live); see the
inventory. **Also 2026-11-01, German dictionary switch:** the six
string-literal German patches (113, 114, 115, 117, 118, 119 — ~2,280 lines,
73% of the layer and its dominant bump cost) were replaced by
`home/lucid-german/en-de.json` (318 exact line rules) applied at build time by
`home/lucid-german/translate.py`; the non-literal hunks stayed as patch 131
and 129 was re-expressed against English context. Proven byte-identical: the
built `lucid-source` store output diffs 0 against the 19-patch output, apart
from the intended 2-line 124 comment fix. See §1
and P3 for the new upkeep model.

---

## 0. Hard rules (always apply, no exceptions)

- **NEVER commit, push, or create PRs.** Stage with `git add` only.
- **NEVER run `nixos-rebuild switch`, `test`, or `boot`, and never reboot.** The
  user activates. Your builds stop at `nix build` / `nixos-rebuild dry-build`.
- **The flake reads the git index, not the working tree.** New or modified files
  are invisible to `nix build` / `nix flake check` / `nix fmt` until `git add`-ed.
  Re-run `git add` after EVERY later edit of the same file.
- `nix fmt` must be given explicit file arguments (`nix fmt <files>`); a bare
  `nix fmt` reads stdin and fails.
- Other sessions may hold unstaged work in the same tree. Never `git checkout`,
  `git restore --staged`, `git reset`, or clean files you did not create. Before
  "fixing" anything you did not change, check `git status` and assume parallel
  work is intentional.
- Work artifacts go under `/tmp/lucid-update-$USER/`. `diff` and `patch` exit 1
  on differences/rejects — never chain them with `&&`.
- `~/.config/quickshell` is the DEPLOYED tree (live user state). NEVER edit,
  rsync into, or delete from it. It is read-only reference material for you.

## 1. System anatomy (facts you may not re-derive)

The chain:

```
flake input `lucid`                      github:Sn3akyy1/lucid, flake = false,
                                         NO ref pin → tracks default branch
  └─ lucidPatched                        stdenv.mkDerivation, home/lucid.nix:44
     │                                   src = lucid input, `patches =` list
     │                                   applied IN LIST ORDER (see table)
     └─ store path  /nix/store/…-lucid-source-<version>-local
                                         version auto-reads upstream's VERSION
                                         file — nothing to bump by hand
        └─ home.activation.lucidSync     rsync -rt --delete INTO the writable
                                         ~/.config/quickshell (stateFiles
                                         excluded + seeded from defaults/;
                                         themes/ synced without --delete)
                                         + repo-managed theme pair
                                         home/lucid-themes/ synced into
                                         ~/.config/lucid/themes/ with an
                                         mtime-equal touch guard (see below)
           └─ lucid.service              systemd USER unit, Restart=always,
                                         KillMode=process, runs
                                         ~/.config/lucid/launch-shell.sh
```

The three pins (lucid, quickshell, dank-greeter) are **deliberately manual** —
`scripts/update-safe` and CI never touch them. Current pins (re-derive, do not
trust this table blindly):

```bash
nix flake metadata --json | jq '.LockedNodes // .locks.nodes
  | {lucid: .lucid.locked.rev, quickshell: .quickshell.locked.rev,
     "dank-greeter": .["dank-greeter"].locked.rev}'
```

### Patch inventory

Since the 2026-11-01 dictionary switch exactly FOURTEEN patches are applied
(the `patches =` list in `home/lucid.nix`, in this order — the struck ~~112~~
row below is historical, not counted) plus the German dictionary
(`home/lucid-german/`, applied after all patches by the postPatch translator):

| # | File | Intent | Files touched | Special |
|---|------|--------|---------------|---------|
| 001 | `001-nixos-paths.patch` | NixOS `.desktop`/icon/theme dirs everywhere upstream scans Arch paths — `luciddocks/Dock.qml` (appScanner + pinLookup + locale-aware names), `luciddocks/resolve-icons.sh` (dirs + `find -L`), `lucidprefs/envtool.py` AND `lucidprefs/cursorshadow.py` (ICON/THEME_DIRS) | 4 | Breaks most visibly if it regresses (launcher finds no apps) |
| 104 | `104-bar-indicators.patch` | Hide the volume percentage `LText` and the mic `Icon` in the compact system pill row (`lucidbar/System.qml`) — v1.20 exposes NO settings for either (only `showKbLayout`) | 1 | Re-born pre-v1.20 patch; if the user ever wants them back, delete the two `visible: false` lines |
| 111 | `111-tray-icons-hidpi.patch` | Raster icons at display resolution: tray bar icon (18dp) + expanded panel (22dp), notification avatars, overview app badges — `sourceSize` at 2x via quickshell `IconImage`'s `backer` alias (no public sourceSize) + proven ActiveWindow pattern | 3 | Scale-2 panel pixelation fix; SVG/theme icons sharpen, fixed-size PNGs can't (no pixels exist) |
| ~~112~~ | *(removed 2026-10-10)* | Superseded natively: the lucidSync migration bakes `clockDateFormat: "numeric"` (renders the locale short format = `10.10.26` under the LANG pin) — no patch surface left | 0 | Flip guard: only from `dayMonth` or `short`; other values are deliberate user choices |
| dict | `home/lucid-german/en-de.json` + `translate.py` (NOT a patch) | German wording layer since 2026-11-01 — replaces former 113/114/115/117/118/119 (~2,280 lines): 318 exact line rules across 33 QML files (lock screen, dashboard incl. wifi/bt panels, weather, notification surfaces, clock app, session screen), applied by the build-time translator in `lucid.nix` postPatch AFTER all patches. Each rule maps one full source line to its full German line verbatim — markers (`// nixos-config local patch 113 (German)` etc.), inline comments and all, reproduced byte-exact | 33 | **Zero-match rule = BUILD FAILURE** (`translate: N unmatched rule(s)`, names file + line) — the .rej equivalent: re-express that one rule from the new upstream line, never hand-edit QML. Upkeep is additive-only: brand-new upstream strings stay English until a rule is added (same policy the P3 mapping rule had). Primary gate for this layer is the P2 build itself |
| 116 | `116-clock-inline-order.patch` | Bar clock INLINE look renders date before time (Date / Clock / Weather — upstream inline is Time · Date); leading date visible unless stacked, trailing dot+date suppressed. Re-expressed 2026-10-28 on upstream's reworked Clock.qml: the date LTexts became bold day+date `Row`s (`dayText`/`dayDateText`, new `lookPref`/`root.look` mechanism) — the same three flips apply to the Rows (`accentFace`→`!stacked` on the leading Row, `false &&` on dot + trailing Row); the leading date in inline inherits upstream's new bold-accent styling | 1 | accent look already ordered Date→time; stacked unchanged. Ordering: ordering-flip only (the clock-app WORDS moved to the dictionary 2026-11-01), 116 stays a patch and must stay before 126 (both touch Clock.qml, disjoint hunks) |
| 121 | `121-plain-dots.patch` | Plain password dots, **v2 pre-v1.20 birth** (user saw the v1 fade-in live 2026-10-12 and preferred the old morph): `lucidui/PasswordEcho.qml` (shared by lock field + polkit AuthCard) — the tessellated `Shape`/PathSvg bead becomes a plain morphing `Rectangle` driven by a new `born` scalar (0 = the caret's own line, `Theme.dp(2)` wide × twice the dot tall, 45% opacity; 1 = the settled `echo.dot` dot, radius-capped pill, no layer needed), and the two-phase `life` ParallelAnimation (pop overshoot → 180ms pause → melt/settle + parallel 900ms twist) becomes SequentialAnimation: lag pause (paste cascade kept) → ScriptAction snaps pop/grow/settle/melt/lit to settled values → single `born` tween `Theme.ms(300)` `easeEmphasizedDecel` — the verbatim v1.1–v1.10.x parameters. `"shape": echo.draw()` → `"circle"` kept for self-documentation (role now unused — PathSvg gone); slot grow snaps instantly = row shift like the pre-v1.20 Repeater | 1 | Only patch touching `lucidui/PasswordEcho.qml` — no ordering constraints. Death fade, reveal morph (`shown`), selection band (`pick`), busy ripple (bob) stay upstream. v1 (fade-in) was live-tested; delete the patch to restore the full v1.20 choreography |
| 122 | `122-ambient-motion-gates.patch` | 2026-10-17 perf round: new pref `Prefs.ambientMotion` (alias + defaults-map entry + inner bool, modeled on `audioMeters`) gates the seven remaining always-on `Animation.Infinite` loops — desktop `WeatherWidget` sun spin, `WeatherIcon` animation clock (desktop + lock consumers via its `live:`), `TimerWidget` dial (**the `w.done` celebratory spin dropped** — it ran at 6s/rev until dismissed), `BatteryWidget` charging ring, `MediaWidget` disc, `lucidui/LinearProgress` wavy flow (one line covers all its consumers: lock media, bar System, weather/media/battery widgets), bar `Mpris` compact-art disc | 10 | Every gate appends `&& Prefs.ambientMotion` to the existing `running:`/`live:` line; lucidSync migration seeds `ambientMotion: false` (absent → false, explicit value wins). Functional pulses stay ungated (Privacy, DockItem urgent, Clock bell). Re-enable per machine: `"ambientMotion": true` in lucidprefs/prefs.json + lucid restart |
| 123 | `123-cava-idle-suppression.patch` | Desktop-visualiser cava only (root `Cava.qml`; the bar's own cava in `Mpris.qml` is upstream-gated and untouched): `framerate = 60` → `30`, and the SplitParser (a) snaps the never-ending `p * 0.78` decay tail to zero below the 0.015 motion cutoff and (b) skips the `root.levels = out` assignment when every band moved < 0.005 (or the band count changed) — a silent visualiser stops repainting instead of re-firing the levels var at the framerate (DMS 2c5a1a2 technique) | 5 | Beat response unchanged (any band ≥ 0.02 assigns); bars still decay smoothly to zero, then the property goes quiet |
| 124 | `124-net-audio-poll-hygiene.patch` | Monitor-event storms rate-limited to one full sweep per 5s via a new `lastEventRefresh` floor in the settle timers: `Net.qml` (nmcli monitor → 700ms debounce → nmcli/netinfo.py sweep — RSSI churn re-arms it constantly) and `Audio.qml` (pactl subscribe / Pipewire nodes → 600ms debounce → full `pactl list` sweep) | 2 + 2 | Direct `refresh()` callers stay instant: user actions, Audio actionProc + respawn watchdog, Net 20s poll, startup. The monitor processes and debounce timers are untouched (they are the change detectors); the bar wifi icon reads native Quickshell.Networking anyway |
| 125 | `125-startup-warmup-defer.patch` | `shell.qml` eager warm-up split: `Component.onCompleted` keeps the touches with t0 ordering requirements (Bt/BtReceive/BtAgent, Net, Idle, Env, Specials, Glass, Monitors, HyprConfig, Notifs, Clip, NightLight, LiveWall, WallTransitions — since 2026-10-28 also upstream's `audioCombine`/`Audio.sink` touch); the 11 inert-at-t0 singletons (KdeConnect, Updates, Users, Polkit, Chrono, Agenda, Zones, Capture, Sounds, Storage, Startup) move into a one-shot 1.5s `Timer` beside it. Re-expressed 2026-10-28: upstream's block gained the audioCombine tail, so hunk 2's delete-list keeps it eager while deferring the same 11 | 1 | ShellRoot's default property is `children: QQmlListProperty&lt;QObject&gt;` (verified in the pinned quickshell 0.3.2 source, `src/core/reload.hpp`) so a plain `Timer` is a legal child. Worst case a consumer instantiates a deferred singleton early anyway — the deferral is pure win, never a break. Note the Updates singleton now self-checks hourly (lucidupdate/, the 2026-10-20 self-updater) — it is deferred but NOT disabled; see the §5 watch row |
| 126 | `126-clock-static-colon.patch` | 2026-10-24 idle round: bar `Clock.qml` stops the per-second repaint — the colon opacity is plain `1` (upstream blinked it 1↔0.35 every second *through a 400ms fade* whenever `clockShowSeconds` was off, i.e. near-continuous bar + blur damage) and the always-on 1s tick becomes minute-aligned while seconds are hidden (`interval: Prefs.clockShowSeconds ? 1000 : (60 - root.now.getSeconds()) * 1000` — the binding re-anchors to the wall-clock minute on every update) | 1 | 116 first when both touch Clock.qml (disjoint hunks). With seconds shown upstream behavior is byte-preserved (the colon was already solid then). Watch: if a future Clock.qml change adds a second consumer of per-second `root.now`, the minute tick starves it — re-check on bump |
| 127 | `127-agenda-sweep-throttle.patch` | 2026-10-24 idle round: `Agenda.qml` reminder sweep timer 1s → 5s — `check()` is minute-granular by design (`minuteKey` dedup, countdown text reads `minuteKey`), so the 1s sweep was pure wake-up churn; worst case a due reminder rings ~4s late | 1 | No patch-ordering partner since 2026-11-01 (the former 118 recurrence strings on the same file are dictionary rules now — the translator runs after all patches, so both apply regardless of order) |
| 128 | `128-fingerprint-off.patch` | 2026-10-24 journal round: `Lockscreen.qml` fingerprint PamContext gated off — upstream arms its second PamContext (config `fingerprint` from the shipped `pam/fingerprint` → bare `pam_fprintd.so`, bypassing `/etc/pam.d`) on EVERY `lockNow()`; this host has no reader and no fprintd in the closure, so each attempt died at dlopen (PAM code 28 "Modul ist nicht bekannt") and the capped backoff retried ~once a minute for as long as the screen stayed locked (~1400 failed attempts/boot). New `readonly property bool fingerEnabled: false` + early return at the top of `startFinger()` (the only entry point: `lockNow` + the retry timer); `stopFinger()` callers and the password `login` PamContext untouched | 2 | Marker grep: `grep -c fingerEnabled Lockscreen.qml` = 2. Re-enabling needs ALL of: flag `true`, `services.fprintd.enable`, actual reader hardware, AND an absolute store path in `pam/fingerprint` (bare name never resolves on NixOS). Only patch touching the Lockscreen fingerprint section — the lock screen's German strings (former 113) are dictionary rules on disjoint lines |
| 129 | `129-wifi-connect-resilience.patch` | 2026-10-24 wifi round: `WifiPanel.qml` connect-failure UX — the 102 watch item hit for cause (post-resume EC rfkill glitch wedged iwd into ~3 min of instant `connect-failed, status: 1`; the panel showed "Kein Passwort … gespeichert" + a password box for the SAVED network, and a re-typed PSK failed identically — zero auth frames ever reached the driver). Removes the forced pre-connect disconnect in `attemptConnect`/`submitPassword` (it raced iwd), adds ONE silent retry (`retryOrFail`, wired into `onConnectionFailed` + the 15 s timeout timer), and for saved networks suppresses both the misleading NoSecrets text (falls back to "Verbindung fehlgeschlagen.") and the password box; from the second manual failed round on, the box IS offered (changed-router-PSK escape hatch). Does NOT auto-heal a hard driver wedge — wifi off/on remains the manual out | 2 | Marker grep: `grep -c maxConnectAttempts lucidbar/WifiPanel.qml` = 2; `grep -c root.activeNetwork.disconnect lucidbar/WifiPanel.qml` = 0 (both forced-disconnect sites removed). Re-expressed 2026-11-01 against ENGLISH context — the old hunks sat on 114's German WifiPanel text, which moved into the dictionary; the German fallback string inside 129's own `+` lines is baked in verbatim (the translator never sees English there) |
| 131 | `131-german-residual.patch` | 2026-11-01: the non-literal German hunks kept as code when 113–119 became dictionary rules: `lucidlock/LockMedia.qml` (marker comment line + German title line), `lucidbar/System.qml` (explicit `Qt.locale("de_DE")` dashboard date — `Qt.formatDate`'s default locale stays English no matter the env), `lucidbar/ClockToday.qml` (weather tile concatenation expressions), `Chrono.qml` (pomodoro announce expression), `lucidbar/SessionMenu.qml` (uptime expression) | 5 | Applies LAST (after 129). Everything wording-only from the former 113–119 lives in the dictionary row above; keeping code semantics here separable from wording there. Hunks carry the original per-patch markers (113/114/115/118/119) ported verbatim |

**Dropped for good at v1.20 (upstream absorbed):** `103` (disk card counts
LVM/LUKS), `105` (tiles user-arrangeable), `109` (password beads upstream).
**Superseded by settings:** `003`+`106` (mpris pill = `mediaHideIdle` pref,
seeded by the lucidSync migration). **Deliberately not re-added (watch):**
`108` 24h reminders (upstream is clock24h-aware), `110` lock layout chip
(re-evaluate if the chip misreads the German layout). `102` wifi connect
resilience sat on this watch list until 2026-10-24, when the predicted
regression hit for cause (post-resume iwd wedge shown as "Kein Passwort …
gespeichert" + password box on a SAVED network) — re-expressed as `129`.
**2026-10-17 perf round (122–125):** DMS-class fixes ported onto v1.20.1 after
a measured idle baseline of quickshell ~8% + Hyprland ~10% of a core (the
shell fed the compositor a steady frame stream; lucid #42/#43 had already
fixed the bar's own loops upstream). No ordering constraints with the German
wording layer (the dictionary translator runs after ALL patches); all four
apply after 121. **2026-10-24 idle round (126–127):** went
live that day via `systemctl --user restart lucid` for 122–125 (quickshell
58→45 ms/s measured); the remaining unconditional repainter was the bar clock
— see rows 126/127.
**Quickshell PR #1049 (QML disk cache) plan ABANDONED 2026-11-01:** the
shelved engine-patch + lucid-pragma plan is not worth its maintenance while
the PR sits unmerged (wrapper replication, extra engine patch). Revisit only
if upstream merges #1049 — then re-evaluate from scratch.
**2026-10-24 journal round (128):** the lock screen's fingerprint PAM was
silently broken since the v1.20.1 activation (first error 2026-10-17 04:01,
boot −2) — no reader, no fprintd, ~one "Modul ist nicht bekannt" triplet per
locked minute — see row 128.
**Attempted and reverted 2026-10-11/12 (120, smooth caret):** five designs in
one day — delegate+Behavior, SmoothCaret follower component, FrameAnimation
lerp, static-id delegate bindings, slot-follower child — every one QC-green
offscreen and dead live. Verified causes: Qt positions the cursorDelegate
imperatively (`updateCursorRectangle` → `setPosition`/`setHeight`, bypassing
Behaviors), and `cursorRectangle` movement never reaches sibling/child
bindings in the live pipeline (v5's instrumentation logged zero movements
after a confirmed hot-reload). If ever revisited, the only untried mechanism
is a Timer polling `cursorRectangle` and writing the follower slot through
the QML path (notification-independent); explicitly rejected to avoid a
sixth round. Full archive: memory `lucid-smoothcaret-plan-2026-10-10`. Full
pre-v1.20 patch texts in git history (`git log -- home/lucid-patches/`,
pre-v1.20 commits). Re-adding any of them means re-expressing its intent per
§2 P3 against the v1.20 tree.

**History note (pre-v1.20):** the former 003/106 pair was order-coupled (106
deleted 003's line) and 101+ were generated against the fully-patched tree.
Header path prefixes varied (`a/`+`b/`, `base/`+`b2/`, `b2/`+`c2/`); all
applied with `patch -p1`. The current 001 is a `diff -ruN` with upstream's
own exclude list (`a/`+`b/`), `-p1`.

### Where the gates live

| Gate | Catches | Where it throws |
|------|---------|-----------------|
| Patch application | upstream drift vs our patches | real build of `lucidPatched` (NOT dry-build — see §2 P2) |
| `stateFilesChecked` | upstream added a state file to `install.sh` excludes | eval of the activation script — error starts `lucid: stateFiles out of sync with upstream install.sh excludes` |
| `quickshellChecked` | quickshell input older than `minQuickshell` (`home/lucid.nix`, currently `"0.3.2"`) | eval of the activation script — error starts `lucid: quickshell … is older than the tested minimum` |

Both eval gates are interpolated as comments into the generated activation
script, so a successful activation build contains the literal lines
`# stateFiles cross-check vs upstream install.sh: ok` and
`# quickshell engine floor: ok` — greppable proof (used in P2/P5 below).

### Repo-managed theme pair (`home/lucid-themes/`, since 2026-10-13)

`lucidSync` rsyncs `home/lucid-themes/` into `~/.config/lucid/themes/` —
currently one merged theme `grayscale` whose `quickshell.json` is the dark
face and `quickshell-light.json` the hand-picked light face (upstream's model
is one look per theme, so the GUI cannot pair two imports across modes; a
merged theme makes the Light-or-dark toggle and the 8/19 timer move between
our two palettes). Two invariants:

- **mtime guard**: `apply-theme.sh` regenerates `quickshell-light.json`
  through `gen-light-palette.py`'s tone inversion whenever `quickshell.json`
  is strictly newer (`-nt`). The sync block touches the light file's mtime
  onto the dark one to keep them equal — same invariant upstream's
  `save_theme` keeps ("the light file is written after the dark one"). If you
  ever edit the palettes in the repo, keep both files' mtimes equal in git
  (checkout order can skew them) — the guard re-pins them at every activation
  anyway, before the shell ever reads them.
- **repo-owned**: hand edits under
  `~/.config/lucid/themes/grayscale/` are converged back at the next
  activation; iterate in the repo. GUI palette edits are safe (the editor
  always saves a NEW theme dir).

This dir sits OUTSIDE `lucidPatched` — pin bumps and patch triage (P2-P5)
never touch it.

### The critical asymmetry

**`nix flake check` and `nixos-rebuild dry-build` do NOT apply patches.** They
evaluate and plan; `lucidPatched` is merely "to build". A completely broken
patch set passes both. The ONLY agent-runnable gate that applies patches is a
real build of the home activation package (next section).

## 2. Scenario A — planned lucid pin bump

Use when the task is "update/bump lucid". Work phase by phase; do not skip
ahead; each phase names its pass criterion.

### P0 — Preflight

**Pin policy (user decision 2026-11-01): bump ONLY to stable tagged releases,
opportunistically — never chase betas.** Each bump is a full runbook session;
stable tags rebase the patch layer against settled code and avoid
upstream-beta breakage (the 1.20.5.5 beta cost a same-day upstream bug: the
Lumen qtmultimedia crash). Standing exception: the pin deliberately SITS on
beta 1.20.5.5 @ `2945eab` (downgrade refused) — the next bump waits for the
next stable tag. Upstream lands patches of interest in flight (e.g. PR #97
"choose what the System module shows" would obsolete 104, PR #98 "cava rests
while nothing plays" would obsolete 123) — check the open PRs when a release
lands.

```bash
cd /home/dk/nixos-config
git status --short                        # snapshot; note parallel work, never touch it
nix flake metadata --json | jq -r '.locks.nodes.lucid.locked.rev'   # OLD rev, record it
mkdir -p /tmp/lucid-update-$USER
```

**Pass:** you know the old rev and the tree state. If `git status` shows changes
to `home/lucid.nix`, `flake.lock`, or `home/lucid-patches/` you did not make,
STOP and report (parallel session).

### P1 — Bump the pin

```bash
nix flake update lucid
nix flake metadata --json | jq -r '.locks.nodes.lucid.locked.rev'   # NEW rev, record it
```

**Pass:** flake.lock's lucid rev changed. (Note: if the rev did NOT change,
upstream hasn't moved — nothing to do; report that.)

### P2 — Real-build gate (applies patches + forces both eval gates)

```bash
cd /home/dk/nixos-config
nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home.activationPackage -L -o /tmp/lucid-update-$USER/act 2>&1 | tee /tmp/lucid-update-$USER/build.log
```

Read the outcome from the log:

| Log contains | Meaning | Go to |
|---|---|---|
| exit 0, no `fuzz`/`offset`/`HUNK` | clean apply | P4 |
| `offset N lines` / `with fuzz` warnings, exit 0 | patches applied but upstream drifted near our hunks — semantic risk | P4, but record each warned file+hunk for P7's expanded smoke-test |
| `HUNK FAILED` / `patching file … FAILED` / `.rej` | one or more patches reject | P3 |
| `translate: N unmatched rule(s)` | upstream reworded/removed line(s) a dictionary rule matches — the German .rej equivalent | P3 (dictionary branch) |
| `previously applied` / `Reversed patch detected` | upstream incorporated our change | P3 (drop branch) |
| `lucid: stateFiles out of sync with upstream install.sh excludes` | eval gate | P4 (stateFiles fix), then back to P2 |
| `lucid: quickshell … is older than the tested minimum` | eval gate | §3 (quickshell must be bumped first), then back to P2 |

On success also verify the gates rendered `ok`:

```bash
grep -F 'stateFiles cross-check vs upstream install.sh: ok' /tmp/lucid-update-$USER/act/activate
grep -F 'quickshell engine floor: ok'               /tmp/lucid-update-$USER/act/activate
```

**Pass:** build exit 0 AND both greps hit.

### P3 — Per-patch triage (only on rejects)

Principle: the deployed tree `~/.config/quickshell` is the reference for each
patch's **intended end state at the OLD base**. You re-express that intent on
the NEW upstream, patch by patch, in list order. Do NOT diff new-upstream
against the deployed tree as a whole — upstream's own changes would be folded
into "our" patches (that recipe is only valid when the pin did not move).

Set up two working trees:

```bash
cd /tmp/lucid-update-$USER
git clone --quiet https://github.com/Sn3akyy1/lucid upstream
git -C upstream checkout --quiet <NEW_REV>            # the P1 rev
cp -r upstream work
```

Apply patches cumulatively, snapshotting before each, regenerating any patch
that needed hand-repair immediately:

```bash
cd /tmp/lucid-update-$USER
for p in /home/dk/nixos-config/home/lucid-patches/*.patch; do
  rm -rf prev && cp -r work prev
  echo "=== $(basename "$p")"
  if patch -d work -p1 --forward < "$p"; then
    :                                                    # applied (possibly with offsets)
  else
    find work -name '*.rej' -print                       # the actual rejects
    # ---- MANUAL REPAIR, per .rej file: ----
    #   1. Read work/<file>.rej (the hunk that failed).
    #   2. Read work/<file> (new-upstream + earlier patches).
    #   3. Read ~/.config/quickshell/<file> (intended end state at the old base).
    #   4. Edit work/<file> so it expresses the patch's intent on the new code.
    #   5. rm work/<file>.rej (and any *.orig).
    #   6. Regenerate THIS patch file:
    #        diff -ruN -x '*.rej' -x '*.orig' prev work \
    #          > "/home/dk/nixos-config/home/lucid-patches/$(basename "$p")"
    #      (diff exits 1 on differences — expected, not an error.)
  fi
done
find work -name '*.rej' -o -name '*.orig'    # MUST print nothing when done
```

**Dictionary branch (P2 threw `translate: N unmatched rule(s)`):** the build
log names each stale rule (file + line). For each one: find the new upstream
line (the rule's `old` line is the pre-2026-11-01 English text), apply the
same German wording, and replace that one rule in
`home/lucid-german/en-de.json` (format: one JSON object per file, keys =
full old line, values = full new line — copy the upstream line and translate
in place). Rules reproduce lines VERBATIM, so keep upstream's markers/comments
out of your head: if upstream changed a comment on that line, the new line is
the truth. Brand-new upstream strings get NO rule (they render English) —
note them for the user. Then re-run P2. Never patch QML by hand for wording.

Decision rules during manual repair:

| Situation | Action |
|---|---|
| Reject is small (moved lines, renamed variable), intent is clear | Hand-repair as above |
| Patch applies as "previously applied / reversed" — upstream fixed it themselves | Delete the patch file AND its entry (with its comment block) from `patches =` in `home/lucid.nix`; note in report. For 101 you may also drop just the affected file's hunks |
| Upstream rewrote the whole area; you cannot tell what the intent maps to | ABORT the loop, restore the patch file (`git restore home/lucid-patches/`), STOP per §7 |
| More than ~half the patches reject | STOP per §7 (offer the full-regeneration option as a user decision — it re-splits the whole layer from the deployed tree and loses per-patch history) |
| Dictionary rule unmatched after upstream reworded | Replace that rule's old line with the new upstream line, translate with the same German wording; new strings → no rule, stay English, note for user |
| Upstream absorbed 104 or 123 (PRs #97 / #98 watch) | Same drop branch as "previously applied" |

**Pass:** the loop completes, no `.rej`/`.orig` remain, changed patch files are
in `home/lucid-patches/`. Then `git add home/lucid-patches/*.patch` (index rule)
and **re-run P2** — pass required before continuing.

### P4 — Eval-gate remedies (if P2 threw a gate error)

`stateFiles` gate: the error prints both lists. For every entry in `upstream:`
missing from `ours:`, add a corresponding element to the `stateFiles` list in
`home/lucid.nix` (pattern: `{ file = "<defaults-file>"; dest = "<path/under/~/.config/quickshell>"; }`
— `file` is the name upstream's `install.sh` seeds from `defaults/`, `dest` is
the exclude path the error showed). Entries in `ours:` but not `upstream:`
should be removed only if upstream genuinely dropped them; otherwise STOP and
report. Then `nix fmt home/lucid.nix`, `git add home/lucid.nix`, back to P2.

`quickshell` floor: do not raise `minQuickshell` speculatively — go to §3,
bump quickshell, come back. The floor value is raised only AFTER the pairing
smoke-test passes (§3).

### P5 — Content gate (prove the patches' content survived)

Extract the built patched tree and check per-patch markers against it:

```bash
ACT=$(nix build .#nixosConfigurations.yoga.config.home-manager.users.dk.home.activationPackage --no-link --print-out-paths)
SRC=$(grep -o '/nix/store/[a-z0-9]*-lucid-source-[^ "'"'"']*' "$ACT/activate" | head -1)
echo "$SRC"    # e.g. /nix/store/…-lucid-source-1.10.5-local
```

Then run every grep in Appendix A against `$SRC`. Each must return the stated
result (present ≥1 line, or 0 for the two absence checks).

Attribution check — every difference from upstream must belong to one of our
patches:

```bash
diff -ruN -x '.git' -x '.github' /tmp/lucid-update-$USER/upstream "$SRC" > /tmp/lucid-update-$USER/attribution.diff
wc -l /tmp/lucid-update-$USER/attribution.diff   # skim the whole file
```

**Pass:** all Appendix A greps correct AND every hunk in `attribution.diff` is
explainable by a row of the patch inventory table (§1) — patch rows OR a
dictionary rule (a rule's old line IS the upstream line, its new line the
German). Unattributable hunks =
a regenerated patch folded in upstream code — fix the patch (P3 rules) and
re-run. A failing GERMAN marker grep means a dictionary rule (or 131) lost
its effect — P3 via the dictionary branch, not a patch repair.

### P6 — QC chain and staging

```bash
cd /home/dk/nixos-config
nix fmt home/lucid.nix                        # only if you touched .nix files
git add flake.lock home/lucid.nix home/lucid-patches/*.patch home/lucid-german/
nix flake check
nixos-rebuild dry-build --flake .#yoga        # structure/eval gate only (NOT patches)
```

**Pass:** `nix flake check` exit 0, dry-build exit 0. (Reminders: re-`git add`
after any later edit; dry-build passing says nothing about patch application —
P2 already proved that.)

### P7 — User relay (you stop here)

Report per §7, then hand the user:

1. `sudo nixos-rebuild switch --flake ~/nixos-config#yoga` (or their usual path).
2. Log out/in is NOT required, but lucid picks up the new tree only after the
   next `home-manager` activation syncs it; if in doubt, reboot.
3. **Always follow a switch that touched the lucid tree/wrapper with
   `systemctl --user restart lucid`** — this includes any locale-dependent
   fix: day/month names resolve from the env the process STARTED with (LANG
   is pinned on lucid.service since 2026-10-10), so a tree hot-reload swaps
   strings but never the locale (the "saturday 10 october" report). — a running quickshell process outlives
   switches: it keeps running the OLD tree/config until it exits (config-load
   failure ≠ process exit, so `Restart=always` never fires — observed
   2026-10-10, cost a phantom regression hunt). Tree (QML) changes hot-reload
   via the shell's own watcher, wrapper/env/unit changes never do; the
   restart is always safe.
4. Smoke-test checklist (keyed to the CURRENT patch inventory + the v1.20
   deployment deltas; re-derive from §1 when the layer changes):

| Check | Proves |
|---|---|
| Bar renders at all; windows keybinds work | baseline |
| SUPER+R launcher lists apps, icons visible | 001 |
| Volume pill shows NO percentage, NO mic icon | 104 |
| Tray/panel + notification app icons crisp (scale-2) | 111 |
| Clock pill plain (no matugen chip), date reads "10.10.26" | prefs migration (clockStyle + clockDateFormat numeric) |
| Media pill appears only while something plays; tray sits next to workspaces | prefs migration (mediaHideIdle) |
| **Next boot:** login greeter works | pairing (§3) |
| UI renders in Google Sans Flex (not the Qt fallback font) | v1.20 font deploy |
| Lock screen fully German (greetings, errors, power menu, weather line) | dict (former 113) |
| Dashboard/wifi/bt panels German (uptime "läuft …", tile names) | dict (former 114) |
| Dashboard header date above the uptime German ("Samstag, 10. Oktober") | 131 (explicit de_DE locale) |
| Session screen (SUPER+Escape) German ("Bis bald, …", "Erneut drücken zum Fortfahren, Esc zum Abbrechen", "Läuft seit …"); power panel header "Energie" + läuft chip | dict + 131 (former 119) |
| Weather conditions/compass German ("Teilweise bewölkt", NO/SO) | dict + 131 (former 115) |
| Windows open/close snappier (windowsIn/out split, no popin), border/fade quick | Hyprland motion block (home/hyprland.nix) |
| Shell animations feel tighter (bar popouts, launcher) | motion prefs (motionScale 0.85, barMotionScale 1.0 — live-tunable in Settings) |
| New v1.20 surfaces: clock app, widgets panel, night-light tile, Storage page, sounds | v1.20 deps/asset sync |
| Start button renders at the bar's end; switching a module's look animates; Settings → About shows the version and does NOT get an Update clicked | new 2026-10-20 upstream (start module, look-switch animation, self-updater — §5 warning row) |
| Bar clock inline look still reads Date · time (not time · date), day/date bold per upstream's new styling | 116 re-expressed 2026-10-28 |
| SUPER+E opens **Nautilus** (2026-11-01 revert — the Lumen bind was pulled back); the launcher can still list Lumen/Lens from their desktop entries | 2026-11-01 revert (files keybind Lumen→nautilus, registrar loop removed) |
| Lumen opens from the launcher (preview pane loads); Lens opens a picture and `lensd` stays quiet | wrapper qt6.qtwebengine + qt6.qtmultimedia + qt6.qtimageformats |
| New 1.20.5.5 surfaces render: desktop edit mode, Poster clock face on the wallpaper, LucidShot toolbar, Jelly motion on panels | upstream beta surfaces (report upstream bugs, do not patch) |
| Expected regressions BY DESIGN (dropped patches, not bugs): lock beads/layout chip = upstream. Wifi saved-network behavior is 129-protected since 2026-10-24 (102 re-expressed) — a lingering "Kein Passwort … gespeichert" now signals a real iwd/driver failure, not the panel bug | §1 dropped list |

## 3. Scenario B — quickshell / dank-greeter bump

quickshell is the engine (own flake input, compiles locally, expect ~5 min);
dank-greeter is the login greeter. Both the shell and the greeter exec the
**system** quickshell — three-way pairing lucid ↔ quickshell ↔ DankGreeter. A
quickshell bump can break lucid at runtime with every patch applying cleanly,
so the greeter/bar/lock smoke-test is mandatory.

```bash
cd /home/dk/nixos-config
git status --short
nix flake update quickshell          # and/or: nix flake update dank-greeter
nix build .#nixosConfigurations.yoga.config.system.build.toplevel -L \
  -o /tmp/lucid-update-$USER/toplevel    # compiles quickshell; ~5 min, exit 0 required
git add flake.lock
nix flake check && nixos-rebuild dry-build --flake .#yoga
```

Only after the user's switch AND smoke-test passes (bar, launcher, lock, and
the **greeter on next boot**): raise `minQuickshell` in `home/lucid.nix` to the
new quickshell version (`nix eval --raw nixpkgs#quickshell.version` or read the
build log), `nix fmt home/lucid.nix`, `git add`, re-run `nix flake check`. The
floor documents the tested pairing — raising it before the test would defeat
its purpose.

## 4. Scenario C — build already broken / unplanned drift

Enter at P2 directly (no P1 — the lock already moved). Extra caution: these
inputs are never auto-bumped. If `flake.lock`'s lucid/quickshell/dank-greeter
rev changed and nobody asked for it, a parallel session or an accidental full
`nix flake update` (no arguments) did it. Check `git diff flake.lock`; if the
change isn't yours and isn't wanted: STOP and report — do not `git restore
flake.lock` on your own unless the user says so (parallel-work rule).

If the user reports lucid problems after a routine `update-safe` run: that
script cannot have bumped lucid/quickshell/greeter — the cause is elsewhere
(nixpkgs stdenv, quickshell runtime deps). Go to §5 runtime table.

## 5. Failure playbook

Diagnosis commands every agent may run (no sudo needed):

```bash
journalctl --user -u lucid -b --no-pager | tail -100     # shell runtime log
journalctl -b -u home-manager-dk.service --no-pager | tail -100   # activation aborts
qs ipc call launcher toggle                               # exercise IPC (opens launcher!)
```

### Build / eval time

| Symptom | Cause | Fix |
|---|---|---|
| `HUNK FAILED` in a real build | upstream moved patched code | P3 |
| `offset` / `fuzz` warnings, build passes | small drift, applied anyway | Verify intent via Appendix A markers; flag affected areas for smoke-test |
| `Reversed (or previously applied) patch detected` | upstream fixed it themselves | Drop the patch (P3 decision table) |
| `lucid: stateFiles out of sync with upstream install.sh excludes — update the list.` | new upstream state file | P4 stateFiles remedy |
| `lucid: quickshell … is older than the tested minimum …` | stale engine pin | §3 |
| `error: getting status of '/nix/store/…-source/<file>': No such file or directory` | new/renamed file not `git add`-ed (index rule) | `git add` the file, re-run |
| flake check / dry-build pass but patches are broken | they never apply patches | Always run the P2 real-build gate |

### Activation time (user switched; switch aborted or settings broken)

| Symptom | Cause | Fix |
|---|---|---|
| HM activation aborts, EACCES around lucidSync | store read-only modes leaking into the live tree (rsync `-a` / plain `cp`); fixed historically by `-rt` + `chmod -R u+rwX` | If lucid.nix sync lines were edited, restore them from the index; otherwise STOP+report with `journalctl -b -u home-manager-dk.service` output |
| `would be clobbered` on a config file | an HM-managed file collides with a lucid-generated one (known: `hypridle` unit name; GTK settings.ini — lucid owns `~/.config/gtk-{3,4}.0/settings.ini`, `gtk.enable = !config.desktop.lucid.enable` in `home/theme.nix`) | Do not add HM units/files with those names; report if one appeared |
| `lucid.service` crash-loops, journal shows `Failed at step EXEC` | `launch-shell.sh` missing → lucidSync never ran (activation aborted earlier) | Read `journalctl -b -u home-manager-dk.service`, fix the FIRST error there |

### Runtime (user switched, shell misbehaves)

| Symptom | Likely patch | Action |
|---|---|---|
| Launcher empty / no apps found | 001 (Dock.qml scanner) | Rebuild gate + Appendix A grep; if markers present, capture `journalctl --user -u lucid -b` and STOP+report |
| Icons unresolved (generic fallbacks) | 001 (resolve-icons.sh / envtool.py) | same |
| English strings (re)appear in lock/dashboard/weather | dictionary rule unmatched → upstream reworded it (build would have FAILED, so more likely a rule was hand-removed) | P3 dictionary branch: re-express the rule |
| One specific setting resets after every rebuild | stateFiles drift (gated since 2026-09-28, so unlikely — check the gate rendered `ok` in P2) | P4 |
| Tray pills missing while media idle (or stuck visible) | NOT a patch — `mediaHideIdle` pref + lucidSync migration | Check `prefs.json` `.mediaHideIdle` and the migration block in `home/lucid.nix`; user Settings edits always win |
| Tray / notification icons pixelated on the scale-2 panel | 111 | Verify `backer.sourceSize` markers; fixed-size PNGs stay slightly soft (no larger source exists) |
| Disk card shows `0 / 932 GB` | 103 was DROPPED (upstream counts LVM/LUKS itself now) | If it still misattributes, report upstream bug, do not resurrect the patch blindly |
| Lock screen: all dots twitch on each keystroke | 109 was DROPPED (upstream feature) | upstream bug → report upstream |
| Lock chip reads wrong layout | 110 was DROPPED — re-evaluate against v1.20 chip | re-express per P3 if confirmed broken |
| Wifi: saved-network click fails / "Kein Passwort … gespeichert" | With 129 live this is a REAL iwd/driver failure — the NoSecrets mapping lies (2026-10-24: EC rfkill glitch after s2idle resume wedged iwd ~3 min; re-typed PSK failed identically, zero auth frames at the kernel). Without 129 (pin bump dropped it): the old upstream bug is back | journalctl -b -u iwd + NetworkManager around the event; wifi off/on toggle heals an rfkill wedge; only if 129 is missing, re-express per P3 |
| Keybinds partly dead | NOT a patch — json.lua loader | Check `$XDG_RUNTIME_DIR/lucid-keybinds-status.json` exists and `hyprctl binds \| grep -c bind` (user-run); then §5 of REPO_OVERVIEW "Lucid deployment" |
| "Lucid vX is out" notification / an Update button in Settings → About | NOT a patch — the upstream **self-updater** (`lucidupdate/`, landed 2026-10-20): an hourly version probe (deferred 1.5s by our 125) plus one deduped notification per new release. Download/install only runs on an explicit click → confirm → **sudo password** | **Never click Update / Install on NixOS** — `install.sh` would overwrite the Nix-synced `~/.config/quickshell` with unpinned upstream (German patches, NixOS paths, pref migrations gone) until the next HM activation re-converges it. Damage is transient and self-healing (rsync + lucid restart after the next switch); if it happens, `sudo nixos-rebuild switch` + `systemctl --user restart lucid` and re-verify the smoke table. Deliberately NOT patched out (minimal scope, one deliberate click + password to trigger) — re-decide if the notification nags |
| Lumen window never opens / SUPER+E dead / Lumen preview pane blank | NOT a patch — Lumen's QML chain (Lumen→LumenWindow→PreviewPane) imports QtWebEngine AND QtMultimedia; any module missing from the wrapper kills the whole window ("a window with an import it can't resolve doesn't load at all"). Realized 2026-11-01: the 2026-10-31 bump wired qtwebengine but skipped qtmultimedia — every Lumen launch died in ~0.5 s | The QML error is NOT in journald — detached `qs -p lumen.qml` instances log only to `/run/user/<uid>/quickshell/by-id/*/log.log` (newest dir = latest attempt; grep for `module "…" is not installed`). Then check the wrapper per module: `strings $(readlink -f $(command -v qs)) \| grep -ciE "qtwebengine\|qtmultimedia"` ≥1 each. Lens variant: `lensd.py` crash-looping once a second (`Namespace GdkPixbuf not available`) = missing `GI_TYPELIB_PATH` — set by desktop-hyprland.nix since 2026-11-01 |
| Every app's file dialog suddenly opens in Lumen (or should and doesn't) | NOT a patch — the `--portal` opt-in (deliberately NOT done by lucidSync) | `lumen --portal` switches dialogs to Lumen, `lumen --portal-off` reverts (writes `~/.config/xdg-desktop-portal/hyprland-portals.conf` + restarts portals) |
| QML syntax errors crash-looping the shell | a repaired patch introduced bad syntax | `journalctl --user -u lucid -b` → the file+line; fix the patch; qmllint sanity: `nix build nixpkgs#qt6.qtdeclarative -o /tmp/qtd` then find qmllint under its `bin/` (lives in qtdeclarative, NOT qttools; the `.bin` output attr no longer exists in current nixpkgs) |
| `module "Qt5Compat.GraphicalEffects" is not installed` (or any other Qt module) at shell load | upstream imports a Qt module that is not a qtbase/qtdeclarative builtin — Arch ships it system-wide, our quickshell wrapper does not carry it | Add the module to the replicated wrapper's `buildInputs` in the flake.nix overlay (`buildInputs = qsUnwrapped.buildInputs ++ [ final.qt6.qt5compat ]`). ⚠️ Do NOT use upstream's `passthru.withModules` — it closes over the ORIGINAL wrapper let-binding and silently discards the overlay's `overrideAttrs` (the 201 engine patch would vanish; see the ⚠️ block in flake.nix). Happened 2026-10-10: v1.20's Workspaces/ShapedImage import Qt5Compat. Gate: `strings $(readlink toplevel/sw/bin/qs) \| grep qt5compat` after a toplevel build |
| Anything not in this table | — | Collect the two journalctl outputs, STOP, report |

## 6. Rollback

Agent-side (repo only; the index holds the last-known-good staged state):

```bash
git status --short      # decide which restore applies
git restore flake.lock home/lucid.nix home/lucid-patches/        # worktree ← index
# if your own broken edits were already staged:
git restore --source=HEAD --staged --worktree flake.lock home/lucid.nix home/lucid-patches/
```

Never do this to files another session changed (§0 parallel-work rule).

User-side (system): boot the previous generation from the boot menu, or
`sudo nixos-rebuild switch --rollback`. The deployed `~/.config/quickshell`
then gets re-synced back by the old activation on next switch.

## 7. Stop conditions and report format

STOP immediately (no further edits) and report when:

- a patch's target area was rewritten upstream so the intent is unclear,
- more than ~half the patches reject,
- a German translation for a new string is genuinely ambiguous,
- flake.lock moved but nobody asked for a bump (§4),
- any runtime failure not covered by §5,
- you would need sudo, a switch, or GUI interaction.

Report format (final message):

```
LUCID UPDATE — OUTCOME
Pin: <old rev> → <new rev>   (or: quickshell <old>→<new>, greeter …)
Patches: applied cleanly N; repaired N (list + one-line why each); dropped N (why)
Gates: P2 real-build <pass/fail>, stateFiles ok?, quickshell floor ok?,
       Appendix A markers <n/n>, attribution diff clean, flake check, dry-build
Untranslated strings (if any): <list for the user to translate>
USER STEPS: switch command; smoke-test rows from §2 P7 that apply
Remaining risk: <warned-fuzz areas, anything unverified>
```

---

## Appendix A — content-gate marker table

Run from the repo root with `$SRC` set to the built `…-lucid-source-*-local`
path (P5). `grep -c` counts lines; expected value in the last column.

| Patch | Command | Expect |
|---|---|---|
| 001 | `grep -c 'nixos-config local patch' "$SRC/luciddocks/Dock.qml" "$SRC/luciddocks/resolve-icons.sh" "$SRC/lucidprefs/envtool.py" "$SRC/lucidprefs/cursorshadow.py"` | ≥1 each |
| 001 | `grep -c '/run/current-system/sw/share/applications' "$SRC/luciddocks/Dock.qml"` | 2 (appScanner + pinLookup) |
| 001 | `grep -c 'find -L' "$SRC/luciddocks/resolve-icons.sh"` | ≥1 |
| 001 | `grep -c 'BEGIN { l = ENVIRON' "$SRC/luciddocks/Dock.qml"` | ≥1 (locale-aware app names) |
| 104 | `grep -c 'nixos-config local patch 104' "$SRC/lucidbar/System.qml"` | 2 (vol label + mic hidden) |
| 111 | `grep -c 'nixos-config local patch 111' "$SRC/lucidbar/SysTray.qml" "$SRC/lucidnotif/NotifAvatar.qml" "$SRC/lucidbar/Workspaces.qml"` | 2 / 1 / 1 |
| dict | the P2 build itself (`translate: N unmatched rule(s)` in the log) | build exit 0 = every rule matched — this is the German layer's PRIMARY gate |
| dict | `grep -c 'Willkommen zurück' "$SRC/Lockscreen.qml"`; `grep -c 'NO", "O", "SO"' "$SRC/WeatherSource.qml"`; `grep -c '"Kalender"' "$SRC/lucidbar/Clock.qml"`; `grep -c 'ausstehend' "$SRC/lucidbar/Notifications.qml"`; `grep -c 'Bis bald' "$SRC/lucidsession/Session.qml"` | 1; 1; 1; **2** (DND + quiet-hours lines — verified 2026-11-01 QC); 1 (dictionary sentinels across five surfaces) |
| dict | `grep -rc 'nixos-config local patch 11[345789]' "$SRC" --include='*.qml' \| awk -F: '{s+=$NF} END {print s}'` (run via bash) | ≥40 (the former 113/114/115/118/119 marker comments are reproduced verbatim by the rules — a collapse means rules lost their marker lines) |
| 131 | `grep -c 'toLocaleDateString(Qt.locale("de_DE")' "$SRC/lucidbar/System.qml"`; `grep -c 'Fühlt sich wie' "$SRC/lucidbar/ClockToday.qml"`; `grep -c 'Zeit für " + Prefs.pomodoroFocus' "$SRC/Chrono.qml"`; `grep -c 'läuft " + (d' "$SRC/lucidbar/SessionMenu.qml"`; `grep -c 'Unbekannter Titel' "$SRC/lucidlock/LockMedia.qml"` | 1 each (the five non-literal German hunks) |
| 114-style extras | `grep -c 'läuft " + d' "$SRC/lucidbar/System.qml"`; `grep -c 'Passwort eingeben' "$SRC/lucidbar/WifiPanel.qml"`; `grep -c 'Koppeln fehlgeschlagen' "$SRC/lucidbar/BluetoothPanel.qml"`; `grep -c 'Bereitschaft' "$SRC/Power.qml"`; `grep -c '"name": "Flugmodus"' "$SRC/Prefs.qml"` | 1 each (dictionary rules from the former 114 — the full 55-grep set of the six former 113–119 rows remains valid byte-for-byte and can be re-run any time) |
| 116 | `grep -c 'nixos-config local patch 116' "$SRC/lucidbar/Clock.qml"` | 3 |
| 121 | `grep -c 'nixos-config local patch 121' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'property real born' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'PathSvg' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'easeEmphasizedDecel' "$SRC/lucidui/PasswordEcho.qml"` | 2; 1; 0 (the Shape is gone — the morph is live); 2 (birth + death shut) |
| 122 | `grep -c 'nixos-config local patch 122' "$SRC/Prefs.qml"`; `grep -c 'Prefs.ambientMotion' "$SRC/lucidwidgets/WeatherWidget.qml" "$SRC/lucidwidgets/WeatherIcon.qml" "$SRC/lucidwidgets/TimerWidget.qml" "$SRC/lucidwidgets/BatteryWidget.qml" "$SRC/lucidwidgets/MediaWidget.qml" "$SRC/lucidui/LinearProgress.qml" "$SRC/lucidbar/Mpris.qml"` | 3 (alias + defaults + inner bool); 1 each |
| 123 | `grep -c 'framerate = 30' "$SRC/Cava.qml"`; `grep -c 'nixos-config local patch 123' "$SRC/Cava.qml"` | 1; 5 |
| 124 | `grep -c 'lastEventRefresh' "$SRC/Net.qml" "$SRC/Audio.qml"`; `grep -c 'nixos-config local patch 124' "$SRC/Net.qml" "$SRC/Audio.qml"` | 3 each (declaration + check + set); 2 each (property comment + settle comment) |
| 125 | `grep -c 'void KdeConnect.installed' "$SRC/shell.qml"`; `grep -c 'local patch 125' "$SRC/shell.qml"`; `grep -c 'interval: 1500' "$SRC/shell.qml"` | 1 (the eager touch is gone — it lives inside the Timer now); 1; 1 |
| 126 | `grep -c 'nixos-config local patch 126' "$SRC/lucidbar/Clock.qml"`; `grep -c 'interval: Prefs.clockShowSeconds ? 1000' "$SRC/lucidbar/Clock.qml"`; `grep -c 'opacity: 1' "$SRC/lucidbar/Clock.qml"` | 2 (tick comment + colon comment); 1; 1 |
| 127 | `grep -c 'nixos-config local patch 127' "$SRC/Agenda.qml"`; `grep -c 'interval: 5000' "$SRC/Agenda.qml"` | 1; 1 |
| 128 | `grep -c 'fingerEnabled' "$SRC/Lockscreen.qml"` | 2 |
| 129 | `grep -c 'maxConnectAttempts' "$SRC/lucidbar/WifiPanel.qml"`; `grep -c 'root.activeNetwork.disconnect' "$SRC/lucidbar/WifiPanel.qml"` | 2; 0 (both forced-disconnect call sites gone) |
| all | `diff -rq -x '.git' <cumulative-patch-tree> "$SRC"` | 0 differences (strongest gate — see §2 P5 attribution) |

Caveats: a marker grep failing while the patch "applied" means a repair or
upstream change hollowed out the patch's effect — treat as a P3 repair, not a
checklist footnote. If upstream renames a symbol inside a marker string, update
this table in the same change (and `git add` it).

## Appendix B — pins as of 2026-10-28

| Input | Rev / version | Note |
|---|---|---|
| lucid | `2945eabacff3ead45835a53433c41ea4b6688b6f` (v1.20.5.5 **beta**, 2026-10-31) | 14 patches + German dictionary as listed in §1; 001 + 111 re-expressed on this base 2026-10-31; German patches → dictionary + 131, 129 re-expressed 2026-11-01. New upstream apps ride the tree sync: Lumen (file manager, `lucidlumen/`), Lens (picture viewer, `lucidlens/`), edit mode (`Edit.qml`/`lucidedit/`), the tonal icon set (`lucidicons/`); `Recorder.qml` is gone (merged into the LucidShot rebuild). New upstream hard requirement: qt6-webengine (Lumen preview) — folded into the flake overlay's quickshell wrapper together with qt6-imageformats and, since 2026-11-01, qt6-multimedia (upstream install.sh's `PKG_REQUIRED` lists all three; the missing multimedia module is what killed the Lumen window). `lucidSync` NO LONGER registers Lumen/Lens or migrates `files` to Lumen — **reverted 2026-11-01**: the `files` keybind migrates Lumen→nautilus while it matches the Lumen default (one guard covers hosts still carrying the 2026-10-31 migration AND fresh seeds, which still ship Lumen), the once-written `lucid.{lumen,lens}.desktop` entries remain for launcher access, and the inode/directory default is nautilus (hand-pin in the persisted `~/.local/share/applications/mimeapps.list` from 2026-11-01). `lumen.lua` (GTK_USE_PORTAL + portal-dialog float rule) deliberately NOT deployed — portal-flow only. Upstream HEAD is a declared beta: new surfaces may be buggy upstream — **bump policy: stable tags only from here (§2 P0), no downgrade past 1.20.5.5** |
| quickshell | `9b0f339b19057f4731bf3b48293307d7ef241671` (0.3.2+, 2026-10-22) | unchanged — pin equals upstream master tip (verified 2026-10-27, no release in sight: v0.3.2 still newest, PR #1049 disk cache still open — the local disk-cache plan is ABANDONED, 2026-11-01, revisit only if upstream merges it); `minQuickshell = "0.3.2"` |
| dank-greeter | `45b82d84d947a2c6491d4f16a5d0a84ee379dfeb` (duxlabs-dev/dux-greeter, 2026-10-31) | greeter, pairs with quickshell; still v2.0.0-line, no newer tag |

v1.20 caveats baked into this bump: upstream docs scope a "Hyprland 0.55.6+"
floor to custom Lua binds only (README states no floor); yoga runs 0.55.4 —
accepted 2026-10-09 (custom Lua binds have worked live on it; 0.55.x patches
are stability backports). nixos-unstable already had Hyprland 0.56.2 at bump
time — a routine nixpkgs bump clears the floor if smoke-testing ever points at
0.55.x instability. New upstream deployment duties replicated here: Google
Sans Flex font (`xdg.dataFile` + fc-cache in lucidSync), prebuilt sounds ride
the tree sync (`assets/sounds/`), `settings`/`plugins`/`lucid-look` lua
modules (latter two see §1 and `home/hyprland.nix`), session/switcher
keybinds appended in place, 9 new feature packages (see the NixOS lucid
block).
