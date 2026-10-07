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
  # Patches live in ./lucid-patches/ (001 paths, 002 German UI, 003 mpris
  # hide; regenerate against a fresh checkout when the lucid pin moves).
  lucidPatched = pkgs.stdenv.mkDerivation {
    pname = "lucid-source";
    # derived from upstream's VERSION file — a pin bump can't leave it stale
    version = "${lib.trim (builtins.readFile (lucidSrc + "/VERSION"))}-local";
    src = lucidSrc;
    patches = [
      ./lucid-patches/001-nixos-paths.patch
      ./lucid-patches/002-german-ui.patch
      ./lucid-patches/003-mpris-hide.patch
      # Cherry-picks from community forks (joeangi fa1261c, joegieee 1f90b01),
      # rebased onto v1.10.5: notification reply-icon path, brightnessctl
      # backlight detection, marquee idle cost, HTTPS geolocation. Droppable
      # one file at a time if a lucid update outpaces them.
      ./lucid-patches/101-fork-bugfixes.patch
      # Saved-network connect resilience: no forced disconnect before
      # ActivateConnection (raced iwd into connect-failed status 1 on every
      # BSS after a manual switch), one silent retry, and no password box
      # for saved networks on failure/timeout.
      ./lucid-patches/102-wifi-connect-resilience.patch
      # 2026-10-07 local fixes, generated against the fully-patched tree:
      # 103 LUKS disk attribution + btrfs dedupe (dashboard showed 0 GB),
      # 104 hide mic indicator + volume percentage label, 105 drop the
      # inert Spielmodus/Energie tiles (no PPD on TLP hosts), 106 media
      # pill shown-state collapses the bar slot (tray no longer floats).
      ./lucid-patches/103-luks-disk-usage.patch
      ./lucid-patches/104-bar-indicators.patch
      ./lucid-patches/105-dashboard-tiles.patch
      ./lucid-patches/106-mpris-shown-slot.patch
      # 2026-10-07: 107 German UI part 2 — full sweep of the non-settings
      # surfaces (bar, lock screen, panels, notifications, OSD, media,
      # polkit, screenshot/OCR, dock/launcher, desktop menu, widgets, emoji
      # picker); upstream has no i18n, so strings stay patch-translated.
      # Also lifts the lock clock into light tones for light themes (the
      # lock scrim is black in both modes).
      # 108 makes the calendar reminder editor honor Prefs.clock24h
      # (validator 0-23, AM/PM toggle hidden, 24h fmtReminderTime) instead
      # of its hardcoded 12h picker.
      ./lucid-patches/107-german-ui-2.patch
      ./lucid-patches/108-calendar-reminder-24h.patch
      # 2026-10-08 lock screen fixes, generated against the fully-patched
      # tree: 109 pools the password beads (an int Repeater model regenerates
      # every delegate per keystroke, re-running the settle animation on all
      # dots at once — now only the newest bead animates), 110 keeps the
      # layout chip readable for long variant names ("German (no dead keys)"
      # truncated to "NO DEA"; short tags like "US" still win).
      ./lucid-patches/109-lockfield-beads.patch
      ./lucid-patches/110-lock-layout-chip.patch
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
  # --exclude list, v1.10.5): excluded from the sync so `--delete` cannot
  # wipe user settings on an update, and seeded from defaults/ when absent.
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
  lucidLuaModules = [
    "json"
    "specials"
    "binds"
    "windowrules"
    "layerrules"
    "glass"
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
  # while the laptop is off self-corrects at next login. Manual flips from
  # the Theme page keep working and last until the next boundary.
  lightHour = 8;
  darkHour = 19;

  # Quickshell engine floor — empirical (upstream lucid declares no
  # requirement; install.sh PKG_REQUIRED is unpinned). 0.3.1 = the version
  # lucid v1.10.5 AND DankGreeter 1.6.2 are tested against (quickshell is
  # pinned via its own flake input since 2026-09-30). Bump together with
  # the lucid pin.
  minQuickshell = "0.3.1";

  # The wrapper mirrors what Prefs.setColorMode does in-QML: Lucid's own
  # set-mode.sh for the palette (matugen re-run in the new mode, current_mode
  # watched by the shell) plus the app-facing theme swaps — gsettings for
  # running and portal-aware clients, and the gtk3/gtk4/gtk2 ini name fields
  # (via lucid's own envtool writer) for freshly launched plain GTK apps.
  # Theme names are owned by
  # home/theme.nix — keep the two pairs below in sync there. The shell
  # re-applies its persisted env prefs at every start (Env.qml envAdopted
  # → envtool.apply), and a manual Theme-page flip persists them — so the
  # wrapper syncs envColorScheme/envGtkTheme/envIconTheme to the flipped
  # mode below, or every lucid restart rewrites the stale last-manual
  # mode over the timer's values (observed 2026-09-30: prefs "dark"
  # re-darkening gsettings in daytime).
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

            # Palette + matugen templates through Lucid's own flip. Fails while no
            # wallpaper is set through lucid yet (matugen has nothing to derive
            # from) — the gsettings swaps below still land, so downgrade to a
            # warning instead of aborting.
            "$HOME/.config/lucid/set-mode.sh" "$mode" \
              || echo "warning: set-mode.sh failed — swapped gsettings only" >&2

            # Wallpaper repair for STATIC themes: set-mode.sh re-applies the
            # image only for matugen/pywal, and impermanence wipes awww's
            # cache (~/.cache/awww) at boot — after a reboot nothing puts the
            # image back (observed 2026-09-30: black desktop, state files
            # intact). Repair only when awww is not showing an image, so
            # boundary flips mid-session don't re-fade the same picture.
            # awww query: "currently displaying: image: <path>" vs
            # "color: <hex>" when nothing is set (verified live 2026-09-30).
            theme="$(cat "$HOME/.cache/current_theme" 2>/dev/null || echo matugen)"
            wallpaper="$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null || true)"
            if [[ "$theme" != matugen && "$theme" != pywal \
                  && -n "$wallpaper" && -f "$wallpaper" ]] \
               && ! awww query 2>/dev/null | grep -q 'image:'; then
              "$HOME/.config/hypr/scripts/wallpaper/set-wallpaper.sh" "$wallpaper" "$mode" \
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
      ${lib.concatMapStrings (s: ''
        if [ ! -s "$QS_DIR/${s.dest}" ]; then
          mkdir -p "$QS_DIR/$(dirname "${s.dest}")"
          cp "$LUCID_SRC/defaults/${s.file}" "$QS_DIR/${s.dest}"
        fi
      '') stateFiles}

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
          Environment = [
            "PATH=${lucidPath}"
            "QT_QPA_PLATFORM=wayland"
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

      # Auto light/dark. One oneshot for all three triggers (08:00, 19:00,
      # session start): the script itself decides which mode the clock calls
      # for unless a mode is passed. Timer-activated AND wanted by the
      # graphical session — the timer unit below shares the base name, so
      # systemd wires them together without an explicit Unit=.
      lucid-auto-mode = {
        Unit = {
          Description = "Lucid light/dark mode: light ${toString lightHour}:00–${toString darkHour}:00, dark otherwise; corrects at login";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lucidAutoMode}/bin/lucid-auto-mode";
          # Same PATH discipline as lucid.service (lucidPath there): set-mode.sh
          # shells out to matugen, awww, jq, python3 — all system deps.
          Environment = [
            "PATH=${lucidPath}"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.lucid-auto-mode = {
      Unit.Description = "Flip Lucid light/dark at ${toString lightHour}:00 and ${toString darkHour}:00";
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
