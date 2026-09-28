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

  # Every file upstream install.sh treats as runtime state (its tar
  # --exclude list, v1.10.5): excluded from the sync so `--delete` cannot
  # wipe user settings on an update, and seeded from defaults/ when absent.
  # Keep in lockstep with upstream: when a lucid update adds a state file
  # there, add it here too — symptom of a miss is exactly one setting
  # resetting after a rebuild (self-healing: re-set it in Lucid Settings).
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
  # matugen, wallpaper scripts, hyprctl) — all system deps.
  lucidPath = "/run/current-system/sw/bin:/etc/profiles/per-user/${mainUser}/bin:%h/.local/bin";

  # Auto light/dark (user decision 2026-09-23: fixed times, NOT solar —
  # darkman is disabled on this host for fighting matugen over GTK, and a
  # trigger that shifts daily is hard to audit). One timer fires at both
  # boundaries; the service also runs at session start, so a boundary missed
  # while the laptop is off self-corrects at next login. Manual flips from
  # the Theme page keep working and last until the next boundary.
  lightHour = 8;
  darkHour = 19;

  # The wrapper mirrors what Prefs.setColorMode does in-QML: Lucid's own
  # set-mode.sh for the palette (matugen re-run in the new mode, current_mode
  # watched by the shell) plus the app-facing theme swaps — gsettings for
  # running and portal-aware clients, and the gtk3/gtk4/gtk2 ini name fields
  # (via lucid's own envtool writer) for freshly launched plain GTK apps.
  # Theme names are owned by
  # home/theme.nix — keep the two pairs below in sync there. prefs
  # envColorScheme deliberately stays "auto": envtool apply only writes
  # color-scheme for dark/light, so it never rewrites these values behind
  # the timer's back.
  lucidAutoMode = pkgs.writeShellApplication {
    name = "lucid-auto-mode";
    runtimeInputs = with pkgs; [
      glib # gsettings
      coreutils # date
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

            # gsettings races the uwsm environment import on the login run
            # (schemas not visible yet → "Keine Schemata installiert",
            # 2026-09-27 boot): retry briefly, then degrade — set-wallpaper.sh
            # has already landed wallpaper + palette, and the next boundary
            # re-applies.
            gs_set() {
              for _ in 1 2 3 4 5; do
                if gsettings set "$@" 2>/dev/null; then
                  return 0
                fi
                sleep 2
              done
              echo "warning: gsettings unavailable, skipped $*" >&2
            }
            gs_set org.gnome.desktop.interface color-scheme "prefer-$mode"
            if [[ "$mode" == light ]]; then
              gtk="${gtkLight}"
              icon="${iconLight}"
            else
              gtk="${gtkDark}"
              icon="${iconDark}"
            fi
            gs_set org.gnome.desktop.interface icon-theme "$icon"
            gs_set org.gnome.desktop.interface gtk-theme "$gtk"

            # Running and portal-aware clients follow gsettings, but a freshly
            # launched plain GTK app reads the ini files instead. Mirror the two
            # names through lucid's own envtool writer — same keys, format and
            # file policy as the apply a manual Theme-page flip triggers. Guarded:
            # if upstream moves the helper, this degrades to gsettings-only.
            if [[ -f "$HOME/.config/quickshell/lucidprefs/envtool.py" ]]; then
              GTK_NAME="$gtk" ICON_NAME="$icon" python3 - <<'PYEOF'
      import os, sys
      sys.path.insert(0, os.path.expanduser("~/.config/quickshell/lucidprefs"))
      import envtool
      common = {
          "gtk-theme-name": os.environ["GTK_NAME"],
          "gtk-icon-theme-name": os.environ["ICON_NAME"],
      }
      for path in (envtool.GTK3, envtool.GTK4):
          envtool.ini_set(path, "Settings", common)
      envtool.gtk2_set(common)
      PYEOF
            fi
    '';
  };
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
      LUCID_SRC="${lucidSrc}"
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
      ${pkgs.rsync}/bin/rsync -rt --delete \
        --exclude 'keybinds.json' --exclude 'wallpaper-outputs.conf' \
        "$LUCID_SRC/support/lucid/" "$LUCID_DIR/"
      if [ ! -s "$LUCID_DIR/keybinds.json" ]; then
        mkdir -p "$LUCID_DIR"
        ${pkgs.jq}/bin/jq \
          '(.binds[] | select(.id == "exit" or .id == "theme" or .id == "launcher-commands" or .id == "settings" or .id == "clipboard" or .id == "float" or .id == "scratchpad" or .id == "reload" or .id == "split" or .id == "focus-left" or .id == "focus-right" or .id == "focus-up" or .id == "focus-down") | .enabled) = false
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

      # Kitty palette seed (2026-09-27 terminal consolidation): kitty.conf
      # includes matugen-colors.conf (home/terminal.nix), which only exists
      # after the first wallpaper ran matugen. Seed it with the same static
      # Nord the non-lucid attrs use so kitty never includes a missing file;
      # matugen overwrites it when the wallpaper applies. install(1) for a
      # defined mode — a plain store cp would land read-only and matugen's
      # rewrite would then fail. WARNING, not fatal: a seed failure must
      # never abort lucidSync — with the sync having already de-patched the
      # tree, an abort here left ALL QML patches unapplied (2026-09-27 boot:
      # wrong kitty-themes path, no launcher apps, media pill back).
      if [ ! -f "$HOME/.config/kitty/matugen-colors.conf" ]; then
        mkdir -p "$HOME/.config/kitty"
        ${pkgs.coreutils}/bin/install -m 644 \
          "${pkgs.kitty-themes}/share/kitty-themes/themes/Nord.conf" \
          "$HOME/.config/kitty/matugen-colors.conf" \
          || echo "warning: kitty Nord seed failed — matugen will provide colors" >&2
      fi

      # Fix modes LAST, covering everything above: rsync -rt copies the
      # store's read-only file modes, and cp-seeded defaults carry the
      # store's 444 as well — both leave lucid unable to save its own
      # settings (observed live: FileView "Write ... Permission denied").
      # u+rwX restores owner write bits while keeping the exec distinction:
      # upstream's 555 store scripts stay executable, 444 data files do
      # not become so.
      chmod -R u+rwX "$QS_DIR" "$LUCID_DIR"

      # Local look-patches over the synced upstream QML — same idea as the
      # old caelestia Panels.qml patch. Marker-guarded ("nixos-config local
      # patch") so re-runs are no-ops; if an upstream edit moves an anchor,
      # the patch just stops applying — re-check after lucid updates.
      #  1) Mpris: hide the bar pill entirely while nothing is playing
      #     (upstream parks a permanent "Nothing playing" pill there).
      #  2)+3) Weather: user wants German. lucid has no i18n, but the whole
      #     translatable surface is the WMO-code table in WeatherSource plus
      #     one "Feels like" label — translated here string-for-string, with
      #     the coordinates the user set in prefs (locationLat/Lon). Remove
      #     this block to go back to English/stock.
      if ! grep -q 'nixos-config local patch' "$QS_DIR/lucidbar/Mpris.qml"; then
        ${pkgs.gnused}/bin/sed -i 's/^    id: root$/    id: root\n    \/\/ nixos-config local patch: only show the media pill while something plays\n    visible: root.player !== null/' "$QS_DIR/lucidbar/Mpris.qml"
      fi
      if ! grep -q 'nixos-config local patch' "$QS_DIR/WeatherSource.qml"; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's/return "Clear";/return "Klar";/' \
          -e 's/return "Mostly Clear";/return "Überwiegend klar";/' \
          -e 's/return "Partly Cloudy";/return "Wolkig";/' \
          -e 's/return "Overcast";/return "Bedeckt";/' \
          -e 's/return "Fog";/return "Nebel";/' \
          -e 's/return "Drizzle";/return "Nieselregen";/' \
          -e 's/return "Rain";/return "Regen";/' \
          -e 's/return "Snow";/return "Schnee";/' \
          -e 's/return "Rain Showers";/return "Regenschauer";/' \
          -e 's/return "Snow Showers";/return "Schneeschauer";/' \
          -e 's/return "Thunderstorm";/return "Gewitter";/' \
          -e 's/^    function ensure() {$/    function ensure() {\n        \/\/ nixos-config local patch: anchor marker for the weather translation/' \
          "$QS_DIR/WeatherSource.qml"
      fi
      if ! grep -q 'nixos-config local patch' "$QS_DIR/lucidbar/Clock.qml"; then
        ${pkgs.gnused}/bin/sed -i 's/"Feels like " + root.feelsLike/"Fühlt sich wie " + root.feelsLike/' "$QS_DIR/lucidbar/Clock.qml"
      fi
      #  4) Launcher app scan (Dock.qml appScanner): upstream hardcodes the
      #     Arch .desktop directories (/usr/share/applications, flatpak,
      #     snapd). On NixOS the entries live in the system/profile env
      #     paths — without them the launcher (win+R) finds no programs at
      #     all and dock pins stay unresolved. Also prefers the
      #     locale-aware Name[xx]= over the untranslated Name= default
      #     (LANG from lucid.service's inherited environment) so launcher
      #     rows and dock pin labels come out in the session language —
      #     pins cache the label at pin time, so re-pin to refresh an
      #     existing one. The last sed stamps the block's guard marker
      #     into the awk tail comment; without it the locale rule would
      #     be appended again on every activation.
      if ! grep -q 'nixos-config local patch' "$QS_DIR/luciddocks/Dock.qml"; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's|for d in /usr/share/applications|for d in /run/current-system/sw/share/applications /etc/profiles/per-user/$USER/share/applications \\"$HOME/.nix-profile/share/applications\\" /usr/share/applications|' \
          -e 's|!insec { next } |!insec { next } /^Name\\\\[/ { k = substr($0, 6); sub(/\\\\].*/, \\"\\", k); if (index(l \\"_\\", k \\"_\\") == 1) name = substr($0, index($0, \\"=\\") + 1) } |' \
          -e 's|BEGINFILE { |BEGIN { l = ENVIRON[\\"LANG\\"]; sub(/[@.].*/, \\"\\", l) } BEGINFILE { |' \
          -e "s|ENDFILE { flush() }'|ENDFILE { flush() } # nixos-config local patch'|" \
          "$QS_DIR/luciddocks/Dock.qml"
      fi
      # Terminal wrapper migration (2026-09-27 kitty consolidation): an
      # already-synced Dock.qml carries the old ghostty swap from patch 4;
      # re-point it at upstream's own "kitty -e". Unguarded — the pattern
      # disappears after the first run, so this is naturally idempotent.
      ${pkgs.gnused}/bin/sed -i 's/ghostty -e /kitty -e /' "$QS_DIR/luciddocks/Dock.qml"
      #  5) Icon resolver (luciddocks/resolve-icons.sh): same story — it
      #     searches /usr/share/icons etc., so the dock fell back to
      #     non-theme icons. Adds the NixOS icon dirs; the theme itself is
      #     read live from gsettings (Fluent-dark, set by home-manager
      #     dconf) and the chain walk picks up its Inherits= from there.
      #     Also find -L: the profile icon dirs are symlink farms into the
      #     nix store, and plain find does not descend into them (icons
      #     silently unresolved, 2026-09-23).
      if ! grep -q 'nixos-config local patch' "$QS_DIR/luciddocks/resolve-icons.sh"; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's|^dirs=.*|dirs="$HOME/.local/share/icons $HOME/.icons /usr/share/icons /usr/local/share/icons /run/current-system/sw/share/icons /etc/profiles/per-user/$USER/share/icons $HOME/.nix-profile/share/icons" # nixos-config local patch|' \
          -e 's|find "$d/$t" \\(|find -L "$d/$t" \\(|' \
          "$QS_DIR/luciddocks/resolve-icons.sh"
      fi

      #  6) Appearance probe (lucidprefs/envtool.py): upstream scans only the
      #     Arch theme paths (~/.icons, ~/.local/share/icons, /usr/share/icons
      #     and the theme equivalents), so on NixOS the probe sees no
      #     home-manager-installed themes and Lucid Settings > Environment
      #     marks "Fluent-dark" as "not installed on this machine any more",
      #     with an empty icon picker and blank previews. The installed lists
      #     also gate Env.variantOf — the light/dark counterpart swap that
      #     runs on every colour-mode change — so the same miss silently
      #     disabled icon/GTK theme switching on a mode flip. Adds the NixOS
      #     profile env paths (basename of HOME is the main user).
      if ! grep -q 'nixos-config local patch' "$QS_DIR/lucidprefs/envtool.py"; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's|^ICON_DIRS = .*|ICON_DIRS = [f"{HOME}/.icons", f"{HOME}/.local/share/icons", "/usr/share/icons", "/run/current-system/sw/share/icons", f"/etc/profiles/per-user/{os.path.basename(HOME)}/share/icons", f"{HOME}/.nix-profile/share/icons"]  # nixos-config local patch|' \
          -e 's|^THEME_DIRS = .*|THEME_DIRS = [f"{HOME}/.themes", f"{HOME}/.local/share/themes", "/usr/share/themes", "/run/current-system/sw/share/themes", f"/etc/profiles/per-user/{os.path.basename(HOME)}/share/themes", f"{HOME}/.nix-profile/share/themes"]  # nixos-config local patch|' \
          "$QS_DIR/lucidprefs/envtool.py"
      fi

      #  7) German UI strings for the daily surfaces: launcher headers and
      #     search field, power menu, quick-settings section titles and
      #     tiles, lock screen. Unlike the behavioral patches above these
      #     are pattern-translations WITHOUT markers — replacing the string
      #     removes the English pattern, so they are naturally idempotent
      #     and re-apply automatically whenever upstream ships the English
      #     text (if upstream renames a string it silently shows English
      #     again — same drift caveat, self-healing by re-set). The
      #     settings app (lucidprefs) is deliberately not translated.
      ${pkgs.gnused}/bin/sed -i \
        -e 's/headerRow("Frequent")/headerRow("Häufig")/' \
        -e 's/headerRow("All applications")/headerRow("Alle Anwendungen")/' \
        "$QS_DIR/luciddocks/Dock.qml"
      ${pkgs.gnused}/bin/sed -i \
        -e 's/"Log Out"/"Abmelden"/' \
        -e 's/"Reboot"/"Neustart"/' \
        -e 's/"Shutdown"/"Herunterfahren"/' \
        -e 's/"Suspend"/"Bereitschaft"/' \
        -e 's/"Hibernate"/"Ruhezustand"/' \
        -e 's/"Lock"/"Sperren"/' \
        "$QS_DIR/luciddocks/PowerRow.qml"
      ${pkgs.gnused}/bin/sed -i \
        -e 's/Search apps, or type > for commands/Apps suchen, »>« für Befehle/' \
        -e 's/Search clipboard history/Zwischenablage durchsuchen/' \
        "$QS_DIR/luciddocks/LauncherFace.qml"
      ${pkgs.gnused}/bin/sed -i \
        -e 's/"Control Centre"/"Kontrollzentrum"/' \
        -e 's/text: "SOUND \& DISPLAY"/text: "KLANG \& ANZEIGE"/' \
        -e 's/"NOW PLAYING"/"LÄUFT GERADE"/' \
        -e 's/text: "DISK"/text: "FESTPLATTE"/' \
        -e 's/name: "Do Not Disturb"/name: "Nicht stören"/' \
        -e 's/name: "Game Mode"/name: "Spielmodus"/' \
        -e 's/name: "Airplane"/name: "Flugmodus"/' \
        -e 's/name: "Wi-Fi"/name: "WLAN"/' \
        -e 's/name: "Location"/name: "Standort"/' \
        -e 's/name: "Power"/name: "Energie"/' \
        -e 's/return "Set up in Settings";/return "In Einstellungen einrichten";/' \
        "$QS_DIR/lucidbar/System.qml"
      ${pkgs.gnused}/bin/sed -i \
        -e 's/"Caps Lock"/"Feststell"/' \
        "$QS_DIR/lucidlock/LockAuthCard.qml"
    '';

    xdg.configFile = {
      # Lucid's reload helper — the SUPER+R bind runs
      # ~/.config/hypr/scripts/reload.sh (just `hyprctl reload`).
      "hypr/scripts/reload.sh" = {
        source = "${lucidSrc}/support/hypr/scripts/reload.sh";
        executable = true;
      };

      # Wallpaper setter. Upstream install.sh deploys support/wallpaper/ to
      # this exact path, which Dock.qml's applyWallpaper execs; without it
      # every wallpaper pick silently no-ops (black screen, no
      # ~/.cache/current_wallpaper, matugen never initializes). The script
      # starts awww-daemon itself on first use.
      "hypr/scripts/wallpaper" = {
        source = "${lucidSrc}/support/wallpaper";
      };
    }
    // (lib.listToAttrs (
      map (name: {
        name = "hypr/modules/${name}.lua";
        value.source = "${lucidSrc}/support/hypr/modules/${name}.lua";
      }) lucidLuaModules
    ))
    // {
      # matugen: templates symlinked from upstream; config authored here
      # with only the templates this setup consumes. The quickshell palette
      # (~/.cache/quickshell/matugen.json) is what Theme.qml reads; the GTK
      # pair lands in the persisted gtk-3.0/gtk-4.0 dirs; kitty gets
      # matugen-colors.conf (included from kitty.conf, home/terminal.nix —
      # lucidSync seeds it with Nord until the first wallpaper lands).
      # Upstream additionally templates starship/vscode/firefox/… — add
      # blocks here before theming those apps. Run with `matugen image
      # <file> -m dark` (that is what Lucid's wallpaper script does).
      "matugen/templates".source = "${lucidSrc}/support/matugen/templates";

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

          [templates.kitty]
          input_path = '~/.config/matugen/templates/kitty.conf'
          output_path = '~/.config/kitty/matugen-colors.conf'
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
          ExecStart = "/run/current-system/sw/bin/awww-daemon";
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
