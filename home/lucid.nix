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
           | (.binds[] | select(.id == "f9-terminal") | .cmd) = "ghostty"' \
          "$LUCID_SRC/support/hypr/keybinds.json" > "$LUCID_DIR/keybinds.json"
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
      #     all and dock pins stay unresolved. Also swaps the hardcoded
      #     "kitty -e" terminal wrapper for ghostty.
      if ! grep -q 'nixos-config local patch' "$QS_DIR/luciddocks/Dock.qml"; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's|for d in /usr/share/applications|for d in /run/current-system/sw/share/applications /etc/profiles/per-user/$USER/share/applications \\"$HOME/.nix-profile/share/applications\\" /usr/share/applications|' \
          -e 's/kitty -e /ghostty -e /' \
          "$QS_DIR/luciddocks/Dock.qml"
      fi
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
    '';

    xdg.configFile = {
      # Lucid's reload helper — the SUPER+R bind runs
      # ~/.config/hypr/scripts/reload.sh (just `hyprctl reload`).
      "hypr/scripts/reload.sh" = {
        source = "${lucidSrc}/support/hypr/scripts/reload.sh";
        executable = true;
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
      # pair lands in the persisted gtk-3.0/gtk-4.0 dirs. Upstream
      # additionally templates kitty/starship/vscode/firefox/… — add blocks
      # here before theming those apps. Run with `matugen image <file> -m
      # dark` (that is what Lucid's wallpaper script does).
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
          # Lucid shells out constantly (python helpers, gdbus, systemctl,
          # matugen, wallpaper scripts, hyprctl). Pin PATH instead of
          # trusting what the user manager inherited — the caelestia lesson:
          # a stripped PATH broke execDetached clicks silently. All system
          # deps are in environment.systemPackages
          # (modules/features/desktop-hyprland.nix, lucid block).
          Environment = [
            "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${mainUser}/bin:%h/.local/bin"
            "QT_QPA_PLATFORM=wayland"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
