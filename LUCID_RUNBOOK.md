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

Last verified against the repo on 2026-10-12 (lucid v1.20 @ `e662954`, 11
patches — the 2026-10-10 polish round (2 passes) re-grew the layer after the
v1.20 "Lucid 2" minimal cut; 112 was then superseded natively; a second round
same day added the dashboard date fix to 114 and new 119; 2026-10-11/12 added
121 (plain password dots), see the inventory).

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
  └─ lucidPatched                        stdenv.mkDerivation, home/lucid.nix:26
     │                                   src = lucid input, `patches =` list
     │                                   applied IN LIST ORDER (see table)
     └─ store path  /nix/store/…-lucid-source-<version>-local
                                         version auto-reads upstream's VERSION
                                         file — nothing to bump by hand
        └─ home.activation.lucidSync     rsync -rt --delete INTO the writable
                                         ~/.config/quickshell (stateFiles
                                         excluded + seeded from defaults/;
                                         themes/ synced without --delete)
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

Since the 2026-10-11 plain-dots round exactly TWELVE patches are applied (the
`patches =` list in `home/lucid.nix`, in this order):

| # | File | Intent | Files touched | Special |
|---|------|--------|---------------|---------|
| 001 | `001-nixos-paths.patch` | NixOS `.desktop`/icon/theme dirs everywhere upstream scans Arch paths — `luciddocks/Dock.qml` (appScanner + pinLookup + locale-aware names), `luciddocks/resolve-icons.sh` (dirs + `find -L`), `lucidprefs/envtool.py` AND `lucidprefs/cursorshadow.py` (ICON/THEME_DIRS) | 4 | Breaks most visibly if it regresses (launcher finds no apps) |
| 104 | `104-bar-indicators.patch` | Hide the volume percentage `LText` and the mic `Icon` in the compact system pill row (`lucidbar/System.qml`) — v1.20 exposes NO settings for either (only `showKbLayout`) | 1 | Re-born pre-v1.20 patch; if the user ever wants them back, delete the two `visible: false` lines |
| 111 | `111-tray-icons-hidpi.patch` | Raster icons at display resolution: tray bar icon (18dp) + expanded panel (22dp), notification avatars, overview app badges — `sourceSize` at 2x via quickshell `IconImage`'s `backer` alias (no public sourceSize) + proven ActiveWindow pattern | 3 | Scale-2 panel pixelation fix; SVG/theme icons sharpen, fixed-size PNGs can't (no pixels exist) |
| ~~112~~ | *(removed 2026-10-10)* | Superseded natively: the lucidSync migration bakes `clockDateFormat: "numeric"` (renders the locale short format = `10.10.26` under the LANG pin) — no patch surface left | 0 | Flip guard: only from `dayMonth` or `short`; other values are deliberate user choices |
| 113 | `113-german-lockscreen.patch` | Lock screen fully German: greetings, PAM/error/status lines, power actions, net/bt labels ("Offline"→"Nicht verbunden"), LockField/LockStatusChips/LockNotifs/LockMedia/LockPower/LockWeather + shared `Notifs.qml` section names (Neu/Heute/Gestern/Älter — user decision 2026-10-07) | 10 | German text IS the marker; quality upgrades over old 002 (Feststelltaste, Wird geprüft…) |
| 114 | `114-german-system.patch` | Dashboard German: uptime, dashboard header DATE (explicit `Qt.locale("de_DE")` — `Qt.formatDate`'s default locale stays English no matter the env, the one date surface the LANG pin cannot reach), sub-view headers, hover tooltips, gauges, battery texts, tile editor, output view + `WifiPanel.qml` + `BluetoothPanel.qml` full inventories + `Power.qml` actions/profiles/degradations + `Prefs.qml` quick-tile DISPLAY names only (keys untouched — Capture/Picker/Scratch/Phone stay English, ambiguous) | 5 | Both 104+114 touch System.qml — non-overlapping hunks, 104 must stay BEFORE 114 in the list |
| 115 | `115-german-weather.patch` | Weather German: `WeatherSource.qml` conditions + German compass (NO/O/SO) + errors (render mid-sentence after "Wetter nicht verfügbar — "), `ClockToday.qml` weather block (feels-like chip, % spacing, "Jetzt"), `WeatherWidget.qml` + `GlanceWidget.qml` | 4 | |
| 116 | `116-clock-inline-order.patch` | Bar clock INLINE look renders date before time (Date / Clock / Weather — upstream inline is Time · Date); leading date visible unless stacked, trailing dot+date suppressed | 1 | accent look already ordered Date→time; stacked unchanged |
| 117 | `117-german-notifs.patch` | Notification surfaces German: `lucidbar/Notifications.qml` (header, status line "N ausstehend", "N weitere", "Alle ausklappen", "Alle löschen" button, empty states), `Notifs.qml` (age stamps jetzt/Min/Std/T, "Unbekannt"), NotifGroup/NotifActions/NotifCard | 5 | Notifs.qml also touched by 113 (disjoint hunks, 113 first) |
| 118 | `118-german-clockapp.patch` | Clock app German: tabs, capture/paused chip, snooze, calendar reminder editor (German plurals), timers incl. full pomodoro block, stopwatch, world clock + `Zones.qml` (Heute/Morgen/Gestern, Gleiche Zeit), `Agenda.qml` recurrence/relative times, `Chrono.qml` labels + notification titles/bodies, `MonthView.qml` weekday initials (M D M D F S S / S M D M D F S) | 10 | 116 first when both touch Clock.qml (disjoint hunks) |
| 119 | `119-german-session.patch` | Session screen + power panel German: `lucidsession/Session.qml` (Bis bald/Erneut drücken/Läuft seit — `Sys.duration()` itself left English-formatted, shared with FetchWidget) + `lucidbar/SessionMenu.qml` ("Energie" header, matching 114's Power.qml wording, + läuft-T/Std/Min uptime chip) | 2 | Untouched by every other patch — no ordering constraints |
| 121 | `121-plain-dots.patch` | Plain password dots, **v2 pre-v1.20 birth** (user saw the v1 fade-in live 2026-10-12 and preferred the old morph): `lucidui/PasswordEcho.qml` (shared by lock field + polkit AuthCard) — the tessellated `Shape`/PathSvg bead becomes a plain morphing `Rectangle` driven by a new `born` scalar (0 = the caret's own line, `Theme.dp(2)` wide × twice the dot tall, 45% opacity; 1 = the settled `echo.dot` dot, radius-capped pill, no layer needed), and the two-phase `life` ParallelAnimation (pop overshoot → 180ms pause → melt/settle + parallel 900ms twist) becomes SequentialAnimation: lag pause (paste cascade kept) → ScriptAction snaps pop/grow/settle/melt/lit to settled values → single `born` tween `Theme.ms(300)` `easeEmphasizedDecel` — the verbatim v1.1–v1.10.x parameters. `"shape": echo.draw()` → `"circle"` kept for self-documentation (role now unused — PathSvg gone); slot grow snaps instantly = row shift like the pre-v1.20 Repeater | 1 | Only patch touching `lucidui/PasswordEcho.qml` — no ordering constraints. Death fade, reveal morph (`shown`), selection band (`pick`), busy ripple (bob) stay upstream. v1 (fade-in) was live-tested; delete the patch to restore the full v1.20 choreography |

**Dropped for good at v1.20 (upstream absorbed):** `103` (disk card counts
LVM/LUKS), `105` (tiles user-arrangeable), `109` (password beads upstream).
**Superseded by settings:** `003`+`106` (mpris pill = `mediaHideIdle` pref,
seeded by the lucidSync migration). **Deliberately not re-added (watch):**
`102` wifi connect resilience (if saved-network clicks time out again,
re-express it), `108` 24h reminders (upstream is clock24h-aware), `110` lock
layout chip (re-evaluate if the chip misreads the German layout).
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
| `quickshellChecked` | quickshell input older than `minQuickshell` (`home/lucid.nix`, currently `"0.3.1"`) | eval of the activation script — error starts `lucid: quickshell … is older than the tested minimum` |

Both eval gates are interpolated as comments into the generated activation
script, so a successful activation build contains the literal lines
`# stateFiles cross-check vs upstream install.sh: ok` and
`# quickshell engine floor: ok` — greppable proof (used in P2/P5 below).

### The critical asymmetry

**`nix flake check` and `nixos-rebuild dry-build` do NOT apply patches.** They
evaluate and plan; `lucidPatched` is merely "to build". A completely broken
patch set passes both. The ONLY agent-runnable gate that applies patches is a
real build of the home activation package (next section).

## 2. Scenario A — planned lucid pin bump

Use when the task is "update/bump lucid". Work phase by phase; do not skip
ahead; each phase names its pass criterion.

### P0 — Preflight

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
    #      For 002/107: find the new upstream English string (the '- ' lines of
    #      the old patch are the old English text) and translate it to the same
    #      German wording used in the deployed tree.
    #   5. rm work/<file>.rej (and any *.orig).
    #   6. Regenerate THIS patch file:
    #        diff -ruN -x '*.rej' -x '*.orig' prev work \
    #          > "/home/dk/nixos-config/home/lucid-patches/$(basename "$p")"
    #      (diff exits 1 on differences — expected, not an error.)
  fi
done
find work -name '*.rej' -o -name '*.orig'    # MUST print nothing when done
```

Decision rules during manual repair:

| Situation | Action |
|---|---|
| Reject is small (moved lines, renamed variable), intent is clear | Hand-repair as above |
| Patch applies as "previously applied / reversed" — upstream fixed it themselves | Delete the patch file AND its entry (with its comment block) from `patches =` in `home/lucid.nix`; note in report. For 101 you may also drop just the affected file's hunks |
| Upstream rewrote the whole area; you cannot tell what the intent maps to | ABORT the loop, restore the patch file (`git restore home/lucid-patches/`), STOP per §7 |
| More than ~half the patches reject | STOP per §7 (offer the full-regeneration option as a user decision — it re-splits the whole layer from the deployed tree and loses per-patch history) |
| German patch (002/107) with a brand-new upstream string not in the old patch | Add its translation only if the string is in the old English→German mapping; otherwise leave English and note it for the user |

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
explainable by a row of the patch inventory table (§1). Unattributable hunks =
a regenerated patch folded in upstream code — fix the patch (P3 rules) and
re-run.

### P6 — QC chain and staging

```bash
cd /home/dk/nixos-config
nix fmt home/lucid.nix                        # only if you touched .nix files
git add flake.lock home/lucid.nix home/lucid-patches/*.patch
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
| Lock screen fully German (greetings, errors, power menu, weather line) | 113 |
| Dashboard/wifi/bt panels German (uptime "läuft …", tile names) | 114 |
| Dashboard header date above the uptime German ("Samstag, 10. Oktober") | 114 (explicit de_DE locale) |
| Session screen (SUPER+Escape) German ("Bis bald, …", "Erneut drücken zum Fortfahren, Esc zum Abbrechen", "Läuft seit …"); power panel header "Energie" + läuft chip | 119 |
| Weather conditions/compass German ("Teilweise bewölkt", NO/SO) | 115 |
| Windows open/close snappier (windowsIn/out split, no popin), border/fade quick | Hyprland motion block (home/hyprland.nix) |
| Shell animations feel tighter (bar popouts, launcher) | motion prefs (motionScale 0.85, barMotionScale 1.0 — live-tunable in Settings) |
| New v1.20 surfaces: clock app, widgets panel, night-light tile, Storage page, sounds | v1.20 deps/asset sync |
| Expected regressions BY DESIGN (dropped patches, not bugs): wifi saved-network behavior = upstream (watch for the old forced-disconnect bug — if it resurfaces, re-express 102); lock beads/layout chip = upstream | §1 dropped list |

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
| English strings (re)appear in lock/dashboard/weather | 113 / 114 / 115 partial reject | P3 German rules |
| One specific setting resets after every rebuild | stateFiles drift (gated since 2026-09-28, so unlikely — check the gate rendered `ok` in P2) | P4 |
| Tray pills missing while media idle (or stuck visible) | NOT a patch — `mediaHideIdle` pref + lucidSync migration | Check `prefs.json` `.mediaHideIdle` and the migration block in `home/lucid.nix`; user Settings edits always win |
| Tray / notification icons pixelated on the scale-2 panel | 111 | Verify `backer.sourceSize` markers; fixed-size PNGs stay slightly soft (no larger source exists) |
| Disk card shows `0 / 932 GB` | 103 was DROPPED (upstream counts LVM/LUKS itself now) | If it still misattributes, report upstream bug, do not resurrect the patch blindly |
| Lock screen: all dots twitch on each keystroke | 109 was DROPPED (upstream feature) | upstream bug → report upstream |
| Lock chip reads wrong layout | 110 was DROPPED — re-evaluate against v1.20 chip | re-express per P3 if confirmed broken |
| Wifi: saved-network clicks time out, password box appears | 102 was DROPPED — the old upstream bug may be back | re-express 102 per P3 from git history |
| Keybinds partly dead | NOT a patch — json.lua loader | Check `$XDG_RUNTIME_DIR/lucid-keybinds-status.json` exists and `hyprctl binds \| grep -c bind` (user-run); then §5 of REPO_OVERVIEW "Lucid deployment" |
| QML syntax errors crash-looping the shell | a repaired patch introduced bad syntax | `journalctl --user -u lucid -b` → the file+line; fix the patch; qmllint sanity: `nix build nixpkgs#qt6.qtdeclarative -o /tmp/qtd` then find qmllint under its `bin/` (lives in qtdeclarative, NOT qttools; the `.bin` output attr no longer exists in current nixpkgs) |
| `module "Qt5Compat.GraphicalEffects" is not installed` (or any other Qt module) at shell load | upstream imports a Qt module that is not a qtbase/qtdeclarative builtin — Arch ships it system-wide, our quickshell wrapper does not carry it | Add the module to the flake.nix overlay: `quickshell = inputs.quickshell.packages.<sys>.quickshell.withModules [ final.qt6.qt5compat ]` (quickshell's own packaging hook — its wrapper folds Qt-module buildInputs into the baked `NIXPKGS_QT6_QML_IMPORT_PATH`; happened 2026-10-10, v1.20's Workspaces/ShapedImage import Qt5Compat). Gate: `strings $(readlink toplevel/sw/bin/qs) \| grep qt5compat` after a toplevel build |
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
| 113 | `grep -c 'Willkommen zurück' "$SRC/Lockscreen.qml"`; `grep -c 'nixos-config local patch 113' "$SRC"/lucidlock/*.qml "$SRC/Notifs.qml"` | 1; ≥1 in all 9 |
| 114 | `grep -c 'läuft " + d' "$SRC/lucidbar/System.qml"`; `grep -c 'toLocaleDateString(Qt.locale("de_DE")' "$SRC/lucidbar/System.qml"`; `grep -c 'Passwort eingeben' "$SRC/lucidbar/WifiPanel.qml"`; `grep -c 'Koppeln fehlgeschlagen' "$SRC/lucidbar/BluetoothPanel.qml"`; `grep -c 'Bereitschaft' "$SRC/Power.qml"`; `grep -c '"name": "Flugmodus"' "$SRC/Prefs.qml"` | 1 each |
| 115 | `grep -c 'Teilweise bewölkt' "$SRC/WeatherSource.qml"`; `grep -c 'NO", "O", "SO"' "$SRC/WeatherSource.qml"`; `grep -c 'Fühlt sich wie' "$SRC/lucidbar/ClockToday.qml"`; `grep -c 'Regenrisiko' "$SRC/lucidwidgets/GlanceWidget.qml"`; `grep -c '"Heute"' "$SRC/lucidwidgets/WeatherWidget.qml"` | 1 each (WeatherWidget 2) |
| 116 | `grep -c 'nixos-config local patch 116' "$SRC/lucidbar/Clock.qml"` | 3 |
| 117 | `grep -c 'ausstehend' "$SRC/lucidbar/Notifications.qml"`; `grep -c 'Alle löschen' "$SRC/lucidbar/Notifications.qml"`; `grep -c 'nixos-config local patch 117' "$SRC/lucidnotif/NotifGroup.qml" "$SRC/lucidnotif/NotifActions.qml" "$SRC/lucidnotif/NotifCard.qml" "$SRC/Notifs.qml"` | 2; 1; ≥1 each |
| 118 | `grep -c '"Kalender"' "$SRC/lucidbar/Clock.qml"`; `grep -c 'Genommene Runden' "$SRC/lucidbar/ClockStopwatch.qml"`; `grep -c '"D", "M", "D"' "$SRC/lucidui/MonthView.qml"`; `grep -c 'Gleiche Zeit' "$SRC/Zones.qml"`; `grep -c 'Zeit für " + Prefs.pomodoroFocus' "$SRC/Chrono.qml"` | 1 each |
| 119 | `grep -c 'läuft " + (d' "$SRC/lucidbar/SessionMenu.qml"`; `grep -c '"Energie"' "$SRC/lucidbar/SessionMenu.qml"`; `grep -c 'Bis bald' "$SRC/lucidsession/Session.qml"`; `grep -c 'Erneut drücken zum Fortfahren' "$SRC/lucidsession/Session.qml"`; `grep -c 'Läuft seit' "$SRC/lucidsession/Session.qml"` | 1 each |
| 121 | `grep -c 'nixos-config local patch 121' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'property real born' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'PathSvg' "$SRC/lucidui/PasswordEcho.qml"`; `grep -c 'easeEmphasizedDecel' "$SRC/lucidui/PasswordEcho.qml"` | 2; 1; 0 (the Shape is gone — the morph is live); 2 (birth + death shut) |
| all | `diff -rq -x '.git' <cumulative-patch-tree> "$SRC"` | 0 differences (strongest gate — see §2 P5 attribution) |

Caveats: a marker grep failing while the patch "applied" means a repair or
upstream change hollowed out the patch's effect — treat as a P3 repair, not a
checklist footnote. If upstream renames a symbol inside a marker string, update
this table in the same change (and `git add` it).

## Appendix B — pins as of 2026-10-10

| Input | Rev / version | Note |
|---|---|---|
| lucid | `e662954f73a39275f214923bb4dab6c85b3800ba` (v1.20, 2026-10-08) | 12 patches as listed in §1 |
| quickshell | `5d5d49873fe8cf1f99ddfd5006ceb2057c5c9b13` (0.3.1, 2026-10-03) | `minQuickshell = "0.3.1"` |
| dank-greeter | `334b2c93d444b65e4fad5b16f3409bcdc013e40f` (1.6.2, 2026-09-27) | greeter, pairs with quickshell |

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
