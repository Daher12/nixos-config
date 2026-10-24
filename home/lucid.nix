{
  config,
  lib,
  pkgs,
  inputs,
  mainUser,
  ...
}:

let
  cfg = config.desktop.lucid;

  # Upstream source (flake input, flake = false — upstream ships no Nix
  # packaging, only an Arch install.sh). The shell tree itself is synced
  # into the WRITABLE ~/.config/quickshell by lucidSync below: Lucid keeps
  # runtime settings inside its own shell directory (lucidprefs/prefs.json,
  # luciddocks/pinned.json, ...), so a read-only store symlink cannot work.
  lucidSrc = inputs.lucid;

  # Upstream tree + downstream patches applied at BUILD time: upstream drift
  # then fails the rebuild loudly (patch rejects), instead of activation-time
  # seds silently stopping. Small drift still applies (GNU patch offsets,
  # visible as warnings in the build log) — that is the intended gradient.
  # Patches live in ./lucid-patches/.
  #
  # 2026-10-09 v1.20 bump ("Lucid 2" rewrite): upstream absorbed or replaced
  # most of the former 13-patch layer (disk attribution, tile removal,
  # password beads, bar arrangement). 2026-10-10 polish round re-grew the
  # layer to nine patches: 001 NixOS paths, 104 bar indicators (volume
  # percentage + mic hidden — no v1.20 setting exists), 111 tray/notif icon
  # hidpi, 113/114/115 German lock screen, dashboard (+ wifi/bt panels) and
  # weather, 116 clock pill inline order (Date/Clock/Weather), 117 German
  # notification surfaces, 118 German clock app (calendar/timers/stopwatch/
  # world/agenda). The former 112 (German clock date separator) was
  # superseded natively: clockDateFormat "numeric" + the LANG pin in
  # lucid.service render 10.10.26 without any patch. Full patch history:
  # git log -- home/lucid-patches/ (pre-v1.20 commits).
  # 2026-10-10 second round: 114 additionally renders the dashboard header
  # date German via an explicit Qt.locale("de_DE") — Qt.formatDate's default
  # locale resolved English regardless of the LANG pin (the one date surface
  # the env could not reach), and 119 Germanizes the session screen
  # (lucidsession/Session.qml) + the power panel header/uptime chip
  # (lucidbar/SessionMenu.qml).
  lucidPatched = pkgs.stdenv.mkDerivation {
    pname = "lucid-source";
    # derived from upstream's VERSION file — a pin bump can't leave it stale
    version = "${lib.trim (builtins.readFile (lucidSrc + "/VERSION"))}-local";
    src = lucidSrc;
    patches = [
      ./lucid-patches/001-nixos-paths.patch
      ./lucid-patches/104-bar-indicators.patch
      ./lucid-patches/111-tray-icons-hidpi.patch
      ./lucid-patches/113-german-lockscreen.patch
      ./lucid-patches/114-german-system.patch
      ./lucid-patches/115-german-weather.patch
      ./lucid-patches/116-clock-inline-order.patch
      ./lucid-patches/117-german-notifs.patch
      ./lucid-patches/118-german-clockapp.patch
      ./lucid-patches/119-german-session.patch
      # 2026-10-12 plain password dots, v2: user saw the v1 fade-in live and
      # preferred the pre-v1.20 birth instead — each typed character starts
      # as the caret's own line (2dp wide, 45% opacity) and settles into the
      # dot over 300ms (easeEmphasizedDecel), like v1.1-v1.10.x. 121 touches
      # only lucidui/PasswordEcho.qml (lock field + polkit AuthCard): the
      # tessellated Shape becomes a morphing Rectangle driven by a `born`
      # scalar; `life` snaps the other scalars and animates only `born`.
      # Busy ripple, backspace fade, reveal and selection stay upstream.
      ./lucid-patches/121-plain-dots.patch
      # 2026-10-17 performance round — DMS-class fixes ported onto v1.20.1.
      # Baseline while idle: quickshell ~8% + Hyprland ~10% of a core, i.e.
      # the shell feeds the compositor a steady frame stream (lucid #42/#43
      # fixed the bar; these cover the stragglers). No ordering constraints
      # with the German layer; all four apply after 121.
      #   122 ambient motion gates — new Prefs.ambientMotion (seeded false by
      #       the lucidSync migration below) gates the seven remaining
      #       always-on infinite animations (desktop weather/timer/battery/
      #       media widgets, wavy progress, bar media disc) + pref plumbing
      #   123 cava idle suppression — framerate 60 -> 30 + epsilon
      #       early-return so a silent visualiser stops repainting
      #       (DMS 2c5a1a2 technique; bar's own cava already gated upstream)
      #   124 net/audio poll hygiene — monitor-event refreshes rate-limited
      #       to one per 5s; user actions and the 20s poll stay instant
      #   125 startup warm-up deferral — the 11 inert-at-t0 singletons move
      #       from shell.qml Component.onCompleted into a 1.5s Timer
      #       (ShellRoot's default property takes any QObject — verified)
      ./lucid-patches/122-ambient-motion-gates.patch
      ./lucid-patches/123-cava-idle-suppression.patch
      ./lucid-patches/124-net-audio-poll-hygiene.patch
      ./lucid-patches/125-startup-warmup-defer.patch
      # 2026-10-24 idle-CPU round two — the last unconditional 1Hz repainter.
      # Measured 2026-10-24 on the pre-round shell: quickshell ~58 +
      # Hyprland ~80 ms/s idle; activating 122-125 (restart alone) cut
      # quickshell to ~45; what remained was the clock blinking the bar
      # colon through a 400ms fade every second even with seconds hidden.
      # Upstream behavior is preserved whenever clockShowSeconds is on.
      #   126 clock static colon — colon opacity 1 (no per-second blink) and
      #       the 1s tick becomes minute-aligned while seconds are hidden
      #   127 agenda sweep throttle — reminder sweep 1s -> 5s (check() is
      #       minute-granular by design; a ring may land ~4s late)
      ./lucid-patches/126-clock-static-colon.patch
      ./lucid-patches/127-agenda-sweep-throttle.patch
      # 2026-10-24 journal hygiene — the lock screen arms upstream's second
      # PamContext ("fingerprint", pam/fingerprint -> pam_fprintd.so) on every
      # lockNow(); this host has no reader and no fprintd in the closure, so
      # each attempt died at dlopen (PAM code 28 "Modul ist nicht bekannt")
      # and the capped backoff retried once a minute for as long as the
      # screen stayed locked (~1400 failed attempts per boot in the journal).
      # A readonly fingerEnabled: false gate at the top of startFinger() —
      # the only entry point (lockNow + the retry timer) — so nothing arms.
      # Re-enabling needs both this flag and a working pam_fprintd (absolute
      # store path in pam/fingerprint + services.fprintd + hardware).
      ./lucid-patches/128-fingerprint-off.patch
      # 2026-10-24 wifi connect resilience — re-expressed pre-v1.20 patch 102
      # (predicted regression in the runbook's watch list; incident
      # 2026-10-24 22:49: minutes after s2idle resume an EC rfkill glitch
      # wedged iwd into 3 min of instant connect-failed status 1, and the
      # panel showed "Kein Passwort … gespeichert" + a password box for the
      # SAVED network — re-typing the PSK failed identically). 129 removes
      # the forced pre-connect disconnect (it raced iwd), adds one silent
      # retry, and for saved networks suppresses both the misleading
      # NoSecrets text and the password box; a second manual connect round
      # after a failure still offers the box (changed-router-PSK escape
      # hatch). A hard driver wedge still needs the wifi off/on toggle.
      ./lucid-patches/129-wifi-connect-resilience.patch
    ];
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true; # byte-identical output to the sed-era tree
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ./. $out/
      runHook postInstall
    '';
  };

  # Every file upstream install.sh treats as runtime state (its tar
  # --exclude list; version tracked by the drift gate below): excluded from
  # the sync so `--delete` cannot wipe user settings on an update, and
  # seeded from defaults/ when absent.
  # Drift-gated: upstreamStateFiles below parses upstream install.sh's
  # excludes; on mismatch the build fails with both lists instead of
  # silently resetting one setting per rebuild (add new files here when
  # the pin moves).
  stateFiles = [
    {
      file = "prefs.json";
      dest = "lucidprefs/prefs.json";
    }
    {
      file = "blur.json";
      dest = "lucidbar/blur.json";
    }
    {
      file = "clock_reminders.json";
      dest = "lucidbar/clock_reminders.json";
    }
    {
      file = "mpris_shazam.json";
      dest = "lucidbar/mpris_shazam.json";
    }
    {
      file = "pinned.json";
      dest = "luciddocks/pinned.json";
    }
    {
      file = "usage.json";
      dest = "luciddocks/usage.json";
    }
    {
      file = "wallpaper.json";
      dest = "luciddocks/wallpaper.json";
    }
    {
      file = "moji-config.json";
      dest = "lucidmoji/config.json";
    }
    {
      file = "moji-state.json";
      dest = "lucidmoji/state.json";
    }
    {
      file = "keys-state.json";
      dest = "lucidkeys/state.json";
    }
    {
      file = "widgets.json";
      dest = "lucidwidgets/widgets.json";
    }
    {
      # upstream ships no default for this one: install.sh only carries an
      # existing icons.json over from its backup, the desktop-icons feature
      # writes it at runtime. Empty `file` = the seed step below skips it;
      # the rsync still excludes it from --delete like every state file.
      file = "";
      dest = "luciddesktop/icons.json";
    }
  ];

  # The same list, parsed out of upstream install.sh at eval time (its tar
  # excludes are hardcoded as --exclude='./<dest>' lines). stateFilesChecked
  # below interpolates the comparison into the lucidSync script text, so a
  # mismatch throws with both lists — caught by flake check and any build.
  upstreamStateFiles =
    lib.pipe (lib.splitString "\n" (builtins.readFile (lucidSrc + "/install.sh")))
      [
        (lib.filter (l: lib.match ".*--exclude='\\./[^']+'.*" l != null))
        (map (l: lib.head (builtins.match ".*--exclude='\\./([^']+)'.*" l)))
      ];

  # Lucid's Hyprland Lua modules required from hyprland.lua (home/hyprland.nix).
  # Deliberately NOT deployed: monitors, autostart, decorations, animations,
  # misc, input, layout, gestures, env — those would override geometry, look
  # and environment values this repo owns declaratively.
  # Hyprland-side Lua modules deployed from the lucid tree. v1.20 adds
  # settings (Settings > Windows/Input pages) and plugins (per-plugin
  # settings + the hypr-dynamic-cursors build hook) — plugins is deployed
  # but deliberately NOT required in home/hyprland.nix: requiring it would
  # imperatively compile a cursor plugin at login. lucid-look lives in
  # support/look/, not modules/, so it has its own xdg entry below.
  lucidLuaModules = [
    "json"
    "specials"
    "binds"
    "windowrules"
    "layerrules"
    "glass"
    "settings"
    "plugins"
  ];

  # Theme/icon names for the auto-mode wrapper's light/dark gsettings swaps —
  # single-sourced from home/theme.nix's desktop.theme options (previously
  # mirrored here as plain let-bindings with a "keep in sync" comment).
  inherit (config.desktop.theme)
    gtkDark
    gtkLight
    iconDark
    iconLight
    ;

  # Pinned PATH for the lucid units (see lucid.service below): the shell and
  # its scripts shell out constantly (python helpers, gdbus, systemctl,
  # matugen, wallpaper scripts, hyprctl) — all system deps. /run/wrappers/bin
  # must come first: dock/launcher children inherit this PATH, and NixOS's
  # privileged helpers (spice-client-glib-usb-acl-helper, fusermount,
  # newuidmap) exist ONLY there — without the dir they resolve to the
  # unelevated store copies and fail (USB redirect: "Error setting facl:
  # Operation not permitted", observed 2026-10-01).
  lucidPath = "/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${mainUser}/bin:%h/.local/bin";

  # Auto light/dark (user decision 2026-09-23: fixed times, NOT solar —
  # darkman is disabled on this host for fighting matugen over GTK, and a
  # trigger that shifts daily is hard to audit). One timer fires at both
  # boundaries; the service also runs at session start, so a boundary missed
  # while the laptop is off self-corrects at next login. Since 2026-10-13 the
  # boundaries drive APPLICATIONS only (user decision 2026-10-13: the shell
  # stays dark) — lucid-shell-dark.service pins the shell's dark face, and
  # only a manual dashboard flip moves it, until the next login.
  lightHour = 8;
  darkHour = 19;

  # Quickshell engine floor — empirical (upstream lucid declares no
  # requirement; install.sh PKG_REQUIRED is unpinned). 0.3.2 = the version
  # lucid v1.20 AND DankGreeter 1.6.2 are tested against (quickshell is
  # pinned via its own flake input since 2026-09-30; 0.3.2 user-verified
  # 2026-10-11). Bump together with the lucid pin.
  minQuickshell = "0.3.2";

  # Apps-side mirror of what Prefs.setColorMode does in-QML for the app half:
  # the app-facing renders (kitty, gtk colors.css, starship, the matugen
  # templates — through lucid's own apply-theme.sh --apps-only) plus gsettings
  # for running and portal-aware clients, and the gtk3/gtk4/gtk2 ini name
  # fields (via lucid's own envtool writer) for freshly launched plain GTK
  # apps. The shell palette is NOT touched: --apps-only leaves
  # ~/.cache/quickshell/matugen.json alone — the shell is pinned dark by
  # lucid-shell-dark.service and only a manual dashboard flip moves it.
  # Theme names are owned by home/theme.nix — keep the two pairs below in
  # sync there. The shell re-applies its persisted env prefs at every start
  # (Env.qml envAdopted → envtool.apply), and a manual Theme-page flip
  # persists them — so the wrapper syncs envColorScheme/envGtkTheme/
  # envIconTheme to the flipped mode below, or every lucid restart rewrites
  # the stale last-manual mode over the timer's values (observed 2026-09-30:
  # prefs "dark" re-darkening gsettings in daytime).
  lucidAutoMode = pkgs.writeShellApplication {
    name = "lucid-auto-mode";
    runtimeInputs = with pkgs; [
      glib # gsettings
      dconf # schema-less fallback for the login-run gsettings race
      jq # lucidprefs/prefs.json env sync
      gnugrep # awww query check in the wallpaper repair
      coreutils # date, mktemp, mv
    ];
    text = ''
            set -euo pipefail

            mode="''${1:-}"
            if [[ -z "$mode" ]]; then
              hour=$(date +%H)
              if (( 10#$hour >= ${toString lightHour} && 10#$hour < ${toString darkHour} )); then
                mode=light
              else
                mode=dark
              fi
            fi
            case "$mode" in
            light | dark) ;;
            *)
              echo "usage: lucid-auto-mode [light|dark]" >&2
              exit 2
              ;;
            esac

            # Apps-only render in the new mode — kitty, gtk colors.css,
            # starship, the matugen templates — through Lucid's own writer.
            # --apps-only leaves the shell palette
            # (~/.cache/quickshell/matugen.json) untouched: the shell is
            # pinned to its dark face (lucid-shell-dark.service) and only
            # applications follow the clock (user decision 2026-10-13).
            # Derived themes (matugen/pywal/colour) have no static palette
            # to render apps-only from and keep the legacy coupled flip.
            theme="$(cat "$HOME/.cache/current_theme" 2>/dev/null || echo matugen)"
            if [[ -f "$HOME/.config/lucid/themes/$theme/quickshell.json" ]]; then
              "$HOME/.config/lucid/apply-theme.sh" --apps-only "$theme" "$mode" \
                || echo "warning: apply-theme.sh --apps-only failed — gsettings swaps only" >&2
            elif [[ "$theme" == matugen || "$theme" == pywal || "$theme" == colour ]]; then
              "$HOME/.config/lucid/set-mode.sh" "$mode" \
                || echo "warning: set-mode.sh failed — swapped gsettings only" >&2
            fi

            # Wallpaper repair for STATIC themes: set-mode.sh re-applies the
            # image only for matugen/pywal, and impermanence wipes awww's
            # cache (~/.cache/awww) at boot — after a reboot nothing puts the
            # image back (observed 2026-09-30: black desktop, state files
            # intact). Repair only when awww is not showing an image, so
            # boundary flips mid-session don't re-fade the same picture.
            # The wallpaper belongs to the pinned-dark shell, so it is
            # re-applied in the SHELL's mode, not the clock's.
            # awww query: "currently displaying: image: <path>" vs
            # "color: <hex>" when nothing is set (verified live 2026-09-30).
            shell_mode="$(cat "$HOME/.cache/current_mode" 2>/dev/null || echo dark)"
            wallpaper="$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null || true)"
            if [[ "$theme" != matugen && "$theme" != pywal \
                  && -n "$wallpaper" && -f "$wallpaper" ]] \
               && ! awww query 2>/dev/null | grep -q 'image:'; then
              "$HOME/.config/hypr/scripts/wallpaper/set-wallpaper.sh" "$wallpaper" "$shell_mode" \
                || echo "warning: wallpaper re-apply failed" >&2
            fi

            # gsettings races the uwsm environment import on the login run
            # (schemas not visible yet → "Keine Schemata installiert",
            # 2026-09-27 boot): retry briefly, then fall back to dconf — it
            # needs no schemas, so it is immune to the race, while writing
            # the same key on the same bus. Without the fallback, Firefox
            # and every color-scheme-following app stayed dark all day
            # (both boots 2026-09-30: all three keys "skipped", ini files
            # light, dconf dark).
            gs_set() {
              key="$1" value="$2"
              for _ in 1 2 3 4 5; do
                if gsettings set org.gnome.desktop.interface "$key" "$value" 2>/dev/null; then
                  return 0
                fi
                sleep 2
              done
              if dconf write "/org/gnome/desktop/interface/$key" "'$value'"; then
                echo "warning: gsettings unavailable, wrote $key=$value via dconf" >&2
                return 0
              fi
              echo "warning: could not write $key at all" >&2
            }
            gs_set color-scheme "prefer-$mode"
            if [[ "$mode" == light ]]; then
              gtk="${gtkLight}"
              icon="${iconLight}"
            else
              gtk="${gtkDark}"
              icon="${iconDark}"
            fi
            gs_set icon-theme "$icon"
            gs_set gtk-theme "$gtk"

            # Keep lucid's persisted env prefs in lockstep with this flip —
            # exactly the payload Prefs.setColorMode persists on a manual
            # Theme-page flip. Left at the last manual flip, every lucid
            # restart re-applied that stale mode over the timer's values
            # (observed 2026-09-30: prefs "dark" re-darkening gsettings in
            # daytime).
            prefs="$HOME/.config/quickshell/lucidprefs/prefs.json"
            if [ -s "$prefs" ]; then
              tmp="$(mktemp "''${prefs}.XXXXXX")"
              if jq --arg scheme "$mode" --arg gtk "$gtk" --arg icon "$icon" \
                '.envColorScheme = $scheme | .envGtkTheme = $gtk | .envIconTheme = $icon' \
                "$prefs" > "$tmp"; then
                mv "$tmp" "$prefs"
              else
                rm -f "$tmp"
              fi
            fi

            # Running and portal-aware clients follow gsettings, but a freshly
            # launched plain GTK app reads the ini files instead. Mirror the two
            # names through lucid's own envtool writer — same keys, format and
            # file policy as the apply a manual Theme-page flip triggers. Guarded:
            # if upstream moves the helper, this degrades to gsettings-only.
            if [[ -f "$HOME/.config/quickshell/lucidprefs/envtool.py" ]]; then
              GTK_NAME="$gtk" ICON_NAME="$icon" MODE="$mode" python3 - <<'PYEOF'
      import os, sys
      sys.path.insert(0, os.path.expanduser("~/.config/quickshell/lucidprefs"))
      import envtool
      common = {
          "gtk-theme-name": os.environ["GTK_NAME"],
          "gtk-icon-theme-name": os.environ["ICON_NAME"],
      }
      for path in (envtool.GTK3, envtool.GTK4):
          envtool.ini_set(path, "Settings", dict(common, **{
              # without this, a manual dark flip leaves prefer-dark=1 behind
              # after the timer flips light (observed live: Colloid-Light-Nord
              # + gtk-application-prefer-dark-theme=1 in the same ini)
              "gtk-application-prefer-dark-theme": "1" if os.environ["MODE"] == "dark" else "0",
          }))
      envtool.gtk2_set(common)
      PYEOF
            fi
    '';
  };

  # Session-start pin: the shell rests on its dark palette (user decision
  # 2026-10-13 — only a manual dashboard flip may leave it, and only until
  # the next login). current_mode is what Prefs.qml watches live (anything
  # not "light" reads dark); the palette itself is re-applied shell-only when
  # the cached one drifted from the dark face (e.g. after an evening of
  # manual light — Theme.qml recolors live from the file watch). Derived
  # themes regenerate through set-mode.sh — for them this is the legacy
  # coupled flip, accepted.
  lucidPinShellDark = pkgs.writeShellApplication {
    name = "lucid-pin-shell-dark";
    runtimeInputs = with pkgs; [
      coreutils # cat (printf/echo are builtins)
      diffutils # cmp
    ];
    text = ''
      set -euo pipefail
      printf '%s' dark > "$HOME/.cache/current_mode"
      theme="$(cat "$HOME/.cache/current_theme" 2>/dev/null || echo matugen)"
      palette="$HOME/.config/lucid/themes/$theme/quickshell.json"
      case "$theme" in
      matugen | pywal | colour)
        "$HOME/.config/lucid/set-mode.sh" dark \
          || echo "warning: set-mode.sh failed; mode file still pinned dark" >&2
        ;;
      *)
        if [[ -f "$palette" ]] && ! cmp -s "$HOME/.cache/quickshell/matugen.json" "$palette"; then
          "$HOME/.config/lucid/apply-theme.sh" --shell-only "$theme" dark \
            || echo "warning: apply-theme.sh --shell-only failed" >&2
        fi
        ;;
      esac
    '';
  };

  # Eval-time drift gate for the list above. Interpolated into the lucidSync
  # script text (always forced when the activation is built), so a mismatch
  # throws with both lists instead of silently resetting one setting per
  # rebuild. Lives inside `config`'s scope: a top-level assert reading
  # cfg.enable recurses through the module-system fixed point.
  stateFilesChecked =
    if
      (lib.sort lib.lessThan upstreamStateFiles) == (lib.sort lib.lessThan (map (s: s.dest) stateFiles))
    then
      "ok"
    else
      throw ''
        lucid: stateFiles out of sync with upstream install.sh excludes — update the list.
        upstream: ${toString (lib.sort lib.lessThan upstreamStateFiles)}
        ours:     ${toString (lib.sort lib.lessThan (map (s: s.dest) stateFiles))}
      '';

  # Engine gate: quickshell rides its own flake input, lucid another —
  # nothing ties them, and a mismatch surfaces as runtime QML breakage.
  # Forced via the same activation-comment interpolation as
  # stateFilesChecked (lazy: unevaluated when the module is disabled).
  quickshellChecked =
    if builtins.compareVersions pkgs.quickshell.version minQuickshell >= 0 then
      "ok"
    else
      throw ''
        lucid: quickshell ${pkgs.quickshell.version} (quickshell flake input)
        is older than the tested minimum ${minQuickshell}. Bump it first:
        nix flake update quickshell
      '';
in
{
  options.desktop.lucid = {
    enable = lib.mkEnableOption "Lucid desktop shell (Quickshell). Pair with features.desktop-hyprland.lucid.enable on the NixOS side";
  };

  config = lib.mkIf cfg.enable {
    # 1) Sync the shell source into the writable shell directory, 2) seed
    # runtime state from defaults/ when absent, 3) install support scripts
    # + the keybind set, 4) wire the GTK color import. Idempotent: the sync
    # is content-addressed by rsync, seeds only fill ABSENT files, so
    # anything changed in Lucid Settings always wins over the defaults.
    home.activation.lucidSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      LUCID_SRC="${lucidPatched}"
      # stateFiles cross-check vs upstream install.sh: ${stateFilesChecked}
      # quickshell engine floor: ${quickshellChecked}
      QS_DIR="$HOME/.config/quickshell"
      LUCID_DIR="$HOME/.config/lucid"

      # Shell tree. --delete keeps lucid updates clean (removed upstream
      # files disappear locally), so EVERY runtime-state file must be in
      # the exclude list — rsync protects excluded files from --delete.
      # Mirrors upstream install.sh's tar excludes 1:1 plus its own
      # scaffolding additions. -rt (NOT -a): rsync -a would copy the nix
      # store's read-only directory modes (r-xr-xr-x) into the live tree,
      # leaving the shell unable to write its own settings and the seed
      # cp failing with EACCES — which aborted the whole HM activation at
      # first boot 2026-09-23 (lucid.service crash-looped on the missing
      # launch-shell.sh).
      mkdir -p "$QS_DIR"
      ${pkgs.rsync}/bin/rsync -rt --delete \
        --exclude '.git' --exclude '.github' --exclude '.claude' \
        --exclude 'support' --exclude 'defaults' --exclude '__pycache__' \
        --exclude 'wallpapers' \
        --exclude 'install.sh' --exclude 'uninstall.sh' \
        --exclude 'README.md' --exclude 'LICENSE' --exclude '.gitignore' \
        ${lib.concatMapStringsSep " \\\n        " (s: "--exclude '${s.dest}'") stateFiles} \
        "$LUCID_SRC/" "$QS_DIR/"

      # Modes EARLY, not only at the end: on a fresh (non-persisted) tree
      # the rsync above just created directories carrying the store's
      # read-only modes — the seed steps below and the keybinds jq write
      # into them and would EACCES-abort the whole activation (the
      # 2026-09-23 failure class; proven by running this script body
      # against a throwaway HOME). The final chmod below stays as the
      # catch-all for everything after this point.
      mkdir -p "$LUCID_DIR"
      chmod -R u+rwX "$QS_DIR" "$LUCID_DIR"

      # Seed-if-absent (upstream's seed step; existing state always wins).
      ${lib.concatMapStrings (
        s:
        lib.optionalString (s.file != "") ''
          if [ ! -s "$QS_DIR/${s.dest}" ]; then
            mkdir -p "$QS_DIR/$(dirname "${s.dest}")"
            cp "$LUCID_SRC/defaults/${s.file}" "$QS_DIR/${s.dest}"
          fi
        ''
      ) stateFiles}

      # support/lucid: launch-shell.sh (Qt render-backend picker) + theme
      # tooling. keybinds.json and wallpaper-outputs.conf are runtime-
      # written by Lucid Settings, so exclude them from --delete and seed
      # keybinds.json only when absent. The seed applies policy edits that
      # align the keymap with the DMS/noctalia muscle memory this setup had
      # before lucid — the compositor-side replacements live in
      # home/hyprland.nix. Everything disabled here stays reachable:
      # theme/wallpaper/power/clipboard through the launcher, Hyprland
      # reload via `hyprctl reload`, and any entry can be re-enabled in
      # Lucid Settings > Keybinds:
      #   exit (SUPER+M)             — exit-Hyprland footgun, dropped long ago
      #   theme (SUPER+T)            — terminal owns SUPER+T (launcher: theme)
      #   launcher-commands (P)      — power menu owns SUPER+P
      #   settings (SUPER+S)         — scratchpad owns SUPER+S (settings: SUPER+comma)
      #   clipboard (SUPER+SHIFT+V)  — float owns it (clipboard: SUPER+V)
      #   float (SUPER+V)            — clipboard owns SUPER+V
      #   scratchpad (SUPER+SHIFT+S) — move-to-magic owns it
      #   reload (SUPER+R)           — launcher owns SUPER+R
      #   split/focus-* (J, arrows)  — bound statically with the same action
      #                                (home/hyprland.nix); avoids duplicate
      #                                compositor binds
      # themes/ is runtime state too: add-theme.py (Lucid Settings theme
      # import) writes ~/.config/lucid/themes/<id>/ — excluded from --delete
      # here and synced separately WITHOUT it, so user imports survive
      # activations while upstream's shipped themes still land/refresh.
      ${pkgs.rsync}/bin/rsync -rt --delete \
        --exclude 'keybinds.json' --exclude 'wallpaper-outputs.conf' \
        --exclude 'themes' \
        "$LUCID_SRC/support/lucid/" "$LUCID_DIR/"
      ${pkgs.rsync}/bin/rsync -rt \
        "$LUCID_SRC/support/lucid/themes/" "$LUCID_DIR/themes/"

      # Repo-managed theme pair (home/lucid-themes/): ONE theme carrying both
      # modes — quickshell.json is the dark face, quickshell-light.json the
      # hand-picked light face. Upstream's model is one theme per look, so the
      # GUI cannot pair two imports across modes; a merged theme makes the
      # Light-or-dark toggle (and the 8/19 timer) move between our two chosen
      # palettes like any normal theme. Repo-owned by design: rsync's
      # quick-check re-asserts this pair at every activation (hand edits under
      # ~/.config/lucid/themes/grayscale/ are converged back — iterate in the
      # repo). The touch guard is load-bearing: apply-theme.sh rebuilds
      # quickshell-light.json through gen-light-palette.py's tone inversion
      # whenever quickshell.json is strictly NEWER (-nt); equal mtimes defeat
      # it, the same invariant upstream's save_theme keeps ("the light file is
      # written after the dark one"). GUI palette edits cannot collide — the
      # editor always saves a NEW theme dir, never this one.
      ${pkgs.rsync}/bin/rsync -rt ${./lucid-themes}/ "$LUCID_DIR/themes/"
      if [ "$LUCID_DIR/themes/grayscale/quickshell.json" -nt "$LUCID_DIR/themes/grayscale/quickshell-light.json" ]; then
        touch -r "$LUCID_DIR/themes/grayscale/quickshell-light.json" "$LUCID_DIR/themes/grayscale/quickshell.json"
      fi
      if [ ! -s "$LUCID_DIR/keybinds.json" ]; then
        mkdir -p "$LUCID_DIR"
        ${pkgs.jq}/bin/jq \
          '(.binds[] | select(.id == "exit" or .id == "theme" or .id == "launcher-commands" or .id == "settings" or .id == "clipboard" or .id == "float" or .id == "scratchpad" or .id == "reload" or .id == "split" or .id == "focus-left" or .id == "focus-right" or .id == "focus-up" or .id == "focus-down" or .id == "f1-mute" or .id == "f2-vol-down" or .id == "f3-vol-up" or .id == "f4-mic-mute" or .id == "f5-bright-down" or .id == "f6-bright-up" or .id == "f8-rfkill" or .id == "f9-terminal" or .id == "f10-lock" or .id == "f12-calc") | .enabled) = false
           | (.binds[] | select(.id == "f9-terminal") | .cmd) = "kitty"' \
          "$LUCID_SRC/support/hypr/keybinds.json" > "$LUCID_DIR/keybinds.json"
      fi
      # 2026-09-27 terminal consolidation (ghostty -> kitty): the seed above
      # only fills an ABSENT keybinds.json, so migrate an existing one in
      # place — but only while F9 still says ghostty (a cmd the user edited
      # in Lucid Settings must survive activations).
      if [ -s "$LUCID_DIR/keybinds.json" ] \
        && ${pkgs.jq}/bin/jq -e '.binds[] | select(.id == "f9-terminal") | .cmd == "ghostty"' \
             "$LUCID_DIR/keybinds.json" > /dev/null; then
        ${pkgs.jq}/bin/jq '(.binds[] | select(.id == "f9-terminal") | .cmd) = "kitty"' \
          "$LUCID_DIR/keybinds.json" > "$LUCID_DIR/keybinds.json.tmp" \
          && mv "$LUCID_DIR/keybinds.json.tmp" "$LUCID_DIR/keybinds.json"
      fi

      # 2026-10-06 F-row fix: upstream lucid binds the BARE F1-F12 to media
      # actions ("Function keys" category). With fn_lock=1 (F-keys default
      # on this EC — proven by evdev capture: bare F1 delivers KEY_F1,
      # Fn+F1 delivers XF86AudioMute) lucid eats every real F-key, so the
      # row ALWAYS acts as media regardless of Fn/FnLock. Disable the bare
      # F-key binds in place; guard on f1-mute still enabled so a user
      # re-enabling single keys in Lucid Settings later survives
      # activations (same pattern as the ghostty->kitty migration above).
      if [ -s "$LUCID_DIR/keybinds.json" ] \
        && ${pkgs.jq}/bin/jq -e '.binds[] | select(.id == "f1-mute") | (.enabled != false)' \
             "$LUCID_DIR/keybinds.json" > /dev/null; then
        ${pkgs.jq}/bin/jq '(.binds[] | select(.id == "f1-mute" or .id == "f2-vol-down" or .id == "f3-vol-up" or .id == "f4-mic-mute" or .id == "f5-bright-down" or .id == "f6-bright-up" or .id == "f8-rfkill" or .id == "f9-terminal" or .id == "f10-lock" or .id == "f12-calc") | .enabled) = false' \
          "$LUCID_DIR/keybinds.json" > "$LUCID_DIR/keybinds.json.tmp" \
          && mv "$LUCID_DIR/keybinds.json.tmp" "$LUCID_DIR/keybinds.json"
      fi

      # 2026-10-09 v1.20: the session screen and the window switcher are new
      # surfaces with new default binds — an existing keybinds.json only
      # gains them through this guarded in-place append (entries verbatim
      # from upstream's support/hypr/keybinds.json; SUPER+Escape and
      # CTRL+ALT+Tab are unbound in home/hyprland.nix, so nothing
      # collides). exit's fallback command gains the hl.dsp.exit() logout
      # fix (plain `dispatch exit` was a no-op on Lua configs) — updated
      # only while it still matches the 1.10.5 default, and it stays
      # disabled (footgun policy, comment above).
      if [ -s "$LUCID_DIR/keybinds.json" ]; then
        ${pkgs.jq}/bin/jq '
          if (.binds | map(.id) | index("session")) == null then .binds += [{ "id": "session", "keys": "SUPER + Escape", "desc": "Session screen: lock, sleep, log out, restart, shut down", "category": "Lucid", "type": "exec", "cmd": "qs ipc call session toggle" }] else . end
          | if (.binds | map(.id) | index("switcher")) == null then .binds += [{ "id": "switcher", "keys": "CTRL + ALT + Tab", "desc": "Window switcher, every workspace", "category": "Windows", "type": "exec", "cmd": "qs ipc call switcher next" }] else . end
          | if (.binds | map(.id) | index("switcher-back")) == null then .binds += [{ "id": "switcher-back", "keys": "CTRL + ALT + SHIFT + Tab", "desc": "Window switcher, stepping back", "category": "Windows", "type": "exec", "cmd": "qs ipc call switcher prev" }] else . end
          | (.binds[] | select(.id == "exit") | select(.cmd == "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit") | .cmd) = "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch \u0027hl.dsp.exit()\u0027"
        ' "$LUCID_DIR/keybinds.json" > "$LUCID_DIR/keybinds.json.tmp" \
          && mv "$LUCID_DIR/keybinds.json.tmp" "$LUCID_DIR/keybinds.json"
      fi

      # 2026-10-10 polish round, look + motion defaults baked as guarded
      # in-place migrations (same flip-only-while-at-old-default pattern as
      # the keybinds migrations above — a value changed in Lucid Settings
      # never gets rewritten):
      #   clockStyle accent -> inline   — no matugen chip on the clock pill,
      #                                   the pill stays plain like the rest
      #                                   of the bar (user request)
      #   mediaHideIdle false -> true   — media pill only occupies bar space
      #                                   while something plays (upstream
      #                                   absorbed the old 003/106 patches
      #                                   as this pref); with the layout
      #                                   left:[workspaces,media,tray] the
      #                                   tray then sits next to workspaces
      #   barMotionScale 1.35 -> 1.0    — bar motion ~35% slower than the
      #                                   rest of the shell by upstream
      #                                   default; 1.0 aligns it (Caelestia/
      #                                   DMS-feel durations, see
      #                                   home/hyprland.nix)
      #   motionScale 1 -> 0.85         — global shell animation speed
      #                                   (upstream seeds the default 1 into
      #                                   prefs.json, so this is a value flip
      #                                   like the others, not an absence
      #                                   seed; a deliberate Settings value
      #                                   other than exactly the default
      #                                   always wins).
      #   clockDateFormat dayMonth|short -> numeric
      #                                   — German clock date without a patch
      #                                   (the former 112): "numeric" renders
      #                                   the locale's short format, which
      #                                   with the LANG=de_DE.UTF-8 pin on
      #                                   lucid.service is 10.10.26. Flipped
      #                                   from dayMonth (upstream default)
      #                                   AND from short (the value the live
      #                                   prefs happened to carry); any other
      #                                   value is a deliberate user choice
      #                                   and wins. The Settings preview
      #                                   uses Qt.locale() too, so it shows
      #                                   the German format natively.
      #   ambientMotion absent -> false  — patch 122's gate for the decorative
      #                                   infinite loops (desktop widget spins,
      #                                   wavy progress flow, bar media disc):
      #                                   each one forces a frame per vsync and
      #                                   keeps Hyprland re-blurring the layer
      #                                   all session (~8%+10% of a core idle).
      #                                   Re-enable per machine: "ambientMotion":
      #                                   true in lucidprefs/prefs.json, then
      #                                   systemctl --user restart lucid.
      # Live-tunable afterwards: Settings > General > Animation speed,
      # Settings > Bar > bar motion + the clock module card.
      if [ -s "$QS_DIR/lucidprefs/prefs.json" ]; then
        ${pkgs.jq}/bin/jq '
          if ((.clockStyle // "accent") == "accent") then .clockStyle = "inline" else . end
          | if ((.mediaHideIdle // false) | not) then .mediaHideIdle = true else . end
          | if ((.barMotionScale // 1.35) == 1.35) then .barMotionScale = 1.0 else . end
          | if ((.motionScale // 1) == 1) then .motionScale = 0.85 else . end
          | if ((.clockDateFormat == "dayMonth") or (.clockDateFormat == "short")) then .clockDateFormat = "numeric" else . end
          | if .ambientMotion == null then .ambientMotion = false else . end
        ' "$QS_DIR/lucidprefs/prefs.json" > "$QS_DIR/lucidprefs/prefs.json.tmp" \
          && mv "$QS_DIR/lucidprefs/prefs.json.tmp" "$QS_DIR/lucidprefs/prefs.json"
      fi

      # GTK colors hook (upstream install.sh): GTK only applies colors.css
      # when gtk.css imports it. The directories also hold home-manager's
      # bookmarks file, but gtk.css itself is a regular writable file.
      for gtkver in 3.0 4.0; do
        gtkdir="$HOME/.config/gtk-$gtkver"
        mkdir -p "$gtkdir"
        if ! grep -q "colors.css" "$gtkdir/gtk.css" 2>/dev/null; then
          printf "@import url('colors.css');\n" >> "$gtkdir/gtk.css"
        fi
      done

      # v1.20 UI font (deployed via xdg.dataFile below): install.sh runs
      # fc-cache after copying it — without a cache refresh the Material You
      # Expressive surfaces silently render in the fallback font. Scoped to
      # the lucid dir and non-fatal so a fontconfig hiccup can never abort
      # the whole activation.
      if [ -d "$HOME/.local/share/fonts/lucid" ]; then
        ${pkgs.fontconfig}/bin/fc-cache -f "$HOME/.local/share/fonts/lucid" \
          || echo "warning: fc-cache failed — UI font may need a manual refresh" >&2
      fi

      # Fix modes LAST, covering everything above: rsync -rt copies the
      # store's read-only file modes, and cp-seeded defaults carry the
      # store's 444 as well — both leave lucid unable to save its own
      # settings (observed live: FileView "Write ... Permission denied").
      # u+rwX restores owner write bits while keeping the exec distinction:
      # upstream's 555 store scripts stay executable, 444 data files do
      # not become so.
      chmod -R u+rwX "$QS_DIR" "$LUCID_DIR"
    '';

    xdg.configFile = {
      # Lucid's reload helper (just `hyprctl reload`). Executed by lucid's
      # `reload` keybind action at exactly this path — disabled in the
      # keybinds.json seed (SUPER+R is the launcher's, home/hyprland.nix),
      # deployed so re-enabling it in Lucid Settings works.
      "hypr/scripts/reload.sh" = {
        source = "${lucidPatched}/support/hypr/scripts/reload.sh";
        executable = true;
      };

      # Wallpaper setter. Upstream install.sh deploys support/wallpaper/ to
      # this exact path, which Dock.qml's applyWallpaper execs; without it
      # every wallpaper pick silently no-ops (black screen, no
      # ~/.cache/current_wallpaper, matugen never initializes). The script
      # starts awww-daemon itself on first use.
      "hypr/scripts/wallpaper" = {
        source = "${lucidPatched}/support/wallpaper";
      };
    }
    // (lib.listToAttrs (
      map (name: {
        name = "hypr/modules/${name}.lua";
        value.source = "${lucidPatched}/support/hypr/modules/${name}.lua";
      }) lucidLuaModules
    ))
    // {
      # v1.20 look module — lives in support/look/, not modules/, so it is
      # outside the lucidLuaModules map above. Fills blur/shadow defaults
      # the shell's own surfaces sample; required in home/hyprland.nix
      # BEFORE that file's own option assignments, so everything Nix sets
      # explicitly still wins.
      "hypr/modules/lucid-look.lua".source = "${lucidPatched}/support/look/lucid-look.lua";

      # matugen: templates symlinked from upstream; config authored here
      # with only the templates this setup consumes. The quickshell palette
      # (~/.cache/quickshell/matugen.json) is what Theme.qml reads; the GTK
      # pair lands in the persisted gtk-3.0/gtk-4.0 dirs. kitty no longer
      # consumes matugen output — static Nord since 2026-09-30
      # (home/terminal.nix); lucid's apply-theme.sh still writes an unused
      # ~/.config/kitty/matugen-colors.conf. Upstream additionally templates
      # starship/vscode/firefox/… — add blocks here before theming those
      # apps. Run with `matugen image <file> -m dark` (that is what Lucid's
      # wallpaper script does).
      "matugen/templates".source = "${lucidPatched}/support/matugen/templates";

      "matugen/config.toml" = {
        # A stale DMS/caelestia-era config.toml from the caelestia
        # experiments must not block HM activation.
        force = true;
        text = ''
          [config]

          [templates.quickshell]
          input_path = '~/.config/matugen/templates/quickshell-colors.json'
          output_path = '~/.cache/quickshell/matugen.json'

          [templates.gtk3]
          input_path = '~/.config/matugen/templates/gtk-colors.css'
          output_path = '~/.config/gtk-3.0/colors.css'

          [templates.gtk4]
          input_path = '~/.config/matugen/templates/gtk-colors.css'
          output_path = '~/.config/gtk-4.0/colors.css'
        '';
      };
    };

    # v1.20 ships its UI font — the Material You Expressive look is drawn
    # with a trimmed 3-axis Google Sans Flex (upstream install.sh copies it
    # to this exact path and runs fc-cache; lucidSync above does the cache
    # refresh). A store-dir symlink is enough: fontconfig caches per real
    # path.
    xdg.dataFile."fonts/lucid".source = "${lucidPatched}/assets/fonts";

    # NOTE: deliberately NO systemd.user.services.hypridle here. Lucid's
    # Idle settings page OWNS the unit name `hypridle` — it generates
    # ~/.config/hypr/hypridle.conf itself and runs `systemctl --user
    # enable/start/stop hypridle` against the hypridle package unit
    # (/run/current-system/sw/share/systemd/user/hypridle.service).
    # An HM unit of the same name claims the same filename
    # (~/.config/systemd/user/hypridle.service) and collides with the
    # symlink Lucid creates → every rebuild fails with "would be
    # clobbered" (2026-09-23). The binary stays available via
    # environment.systemPackages (modules/features/desktop-hyprland.nix).
    systemd.user.services = {
      # The shell itself. launch-shell.sh picks the Qt render backend
      # (Vulkan only on proprietary NVIDIA) and execs `quickshell` — the
      # default config instance, i.e. ~/.config/quickshell/shell.qml that
      # lucidSync deploys. Same target discipline as the old dms.service:
      # After/PartOf graphical-session.target, NEVER a uwsm instance target
      # (ordering cycle — see modules/features/desktop-hyprland.nix).
      # StartLimitIntervalSec=0 so a clean exit still restarts (the shell
      # quits 0 when Hyprland restarts it via its reload flow).
      lucid = {
        Unit = {
          Description = "Lucid desktop shell (Quickshell)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${config.home.homeDirectory}/.config/lucid/launch-shell.sh";
          Restart = "always";
          RestartSec = 1;
          # Default KillMode=control-group kills this unit's whole cgroup on
          # restart — dock/launcher spawns are execDetached children and live
          # there, so every shell restart took them down too (2026-09-26: a
          # reload closed a zcode session started from the dock). process
          # only replaces quickshell itself; helpers like wl-paste watchers
          # survive and self-exit via SIGPIPE once their pipe closes.
          KillMode = "process";
          # Pin PATH instead of trusting what the user manager inherited —
          # the caelestia lesson: a stripped PATH broke execDetached clicks
          # silently. All system deps are in environment.systemPackages
          # (modules/features/desktop-hyprland.nix, lucid block).
          #
          # LANG is pinned for the same reason QML changes never hot-reload
          # the locale: Qt.locale() resolves from the env the process STARTED
          # with, so a shell that came up before the session env landed keeps
          # rendering English day/month names ("saturday 10 october",
          # 2026-10-10) even though `systemctl --user show-environment` says
          # de_DE.UTF-8. Env never hot-reloads — this line takes effect only
          # at the next `systemctl --user restart lucid`.
          # Limits (2026-10-10): the LANG pin never reached the dashboard
          # header date — QML's Qt.formatDate uses Qt's default locale which
          # stayed English — so patch 114 now formats it with an explicit
          # Qt.locale("de_DE"); the pin still drives every
          # toLocaleDateString(Qt.locale(), …) surface (lock screen, clock
          # app, widgets) and the numeric clockDateFormat.
          #
          # GSETTINGS_SCHEMA_DIR + GIO_EXTRA_MODULES make gsettings work
          # inside this unit at all: NixOS app gtk apps get both injected by
          # their wrappers, but the bare session env carries neither —
          # "No schemas installed" (unit env repro 2026-10-10), which starved
          # lucid's IconTheme.qml gsettings get/monitor watcher (themeName
          # stuck at "" → resolve-icons.sh never ran) and forced the dconf
          # fallback in lucid-auto-mode. Schema dir alone is actively wrong:
          # without the dconf GIO module gsettings reads defaults ("Adwaita")
          # instead of the live dconf db — both vars verified returning
          # 'Fluent' under the exact unit env before enabling.
          Environment = [
            "PATH=${lucidPath}"
            "QT_QPA_PLATFORM=wayland"
            "LANG=de_DE.UTF-8"
            "GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
            "GIO_EXTRA_MODULES=${pkgs.dconf.lib}/lib/gio/modules"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Wallpaper daemon, supervised. set-wallpaper.sh starts one on demand,
      # but a daemon spawned as a background child of the lucid-auto-mode
      # oneshot lived in that unit's cgroup — when the unit deactivated, the
      # daemon went with it and the desktop went black after every boot
      # (2026-09-27), fixed only by manually re-picking the wallpaper. A
      # supervised service is up before the shell applies state and restarts
      # on crashes; set-wallpaper.sh's `awww query` check cooperates.
      awww-daemon = {
        Unit = {
          Description = "awww wallpaper daemon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.awww}/bin/awww-daemon";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Apps-only auto light/dark. One oneshot for all three triggers (08:00,
      # 19:00, session start): the script itself decides which mode the clock
      # calls for unless a mode is passed. The SHELL is not touched here —
      # lucid-shell-dark below pins it dark. Timer-activated AND wanted by
      # the graphical session — the timer unit below shares the base name, so
      # systemd wires them together without an explicit Unit=.
      lucid-auto-mode = {
        Unit = {
          Description = "Lucid apps light/dark: light ${toString lightHour}:00–${toString darkHour}:00, dark otherwise; corrects at login (shell pinned dark)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lucidAutoMode}/bin/lucid-auto-mode";
          # Same PATH discipline as lucid.service (lucidPath there):
          # apply-theme.sh/set-mode.sh shell out to matugen, awww, jq,
          # python3 — all system deps.
          Environment = [
            "PATH=${lucidPath}"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Login pin for the SHELL (see lucidPinShellDark above). A separate
      # oneshot rather than an ExecStartPre on lucid.service: lucid's
      # Restart=always would re-darken a manual light flip after every
      # crash-restart, while this runs once per login.
      lucid-shell-dark = {
        Unit = {
          Description = "Pin the Lucid shell to its dark palette (apps keep auto light/dark)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lucidPinShellDark}/bin/lucid-pin-shell-dark";
          # apply-theme.sh shells out to python3/jq; current_mode write needs
          # the same PATH discipline as the units above.
          Environment = [
            "PATH=${lucidPath}"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.lucid-auto-mode = {
      Unit.Description = "Flip Lucid apps light/dark at ${toString lightHour}:00 and ${toString darkHour}:00 (shell stays dark)";
      Timer = {
        OnCalendar = [
          "*-*-* ${toString lightHour}:00:00"
          "*-*-* ${toString darkHour}:00:00"
        ];
        # A boundary missed while powered off is not caught up retroactively —
        # the login run of lucid-auto-mode.service applies the correct mode
        # for the current time instead.
        Persistent = false;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
