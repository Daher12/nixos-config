{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.desktop.noctalia;

  # Declarative Noctalia config (programs.noctalia.settings) renders as a
  # store-symlinked ~/.config/noctalia/config.toml that the shell never
  # rewrites — GUI edits land in ~/.local/state/noctalia/settings.toml and
  # win (layered config: state > config dir; the state dir persists via
  # hosts/yoga/home.nix). Build-time validation runs `noctalia config
  # validate` (checkConfig default): an unknown key fails the dry-build —
  # fix the key, never disable checkConfig. Harvest live tuning back here
  # with `noctalia config export merged`. Layer-of-record harvests so far:
  # 2026-11-08 (full state strip) and 2026-11-15 (second drift incl. the
  # wallpaper-M3 theme). Backups of the stripped state live in the
  # PERSISTED state dir (~/.local/state/noctalia/settings.toml.bak-*) —
  # the earlier /tmp copies died with tmpfs. The suspend timeout is the
  # one key that legitimately re-materializes in state (the power hooks
  # config-set it).
  wallpaperDir = "${config.home.homeDirectory}/Bilder/wallpapers";

  # Google Sans Flex — the shell's UI font, vendored into the repo (copied
  # from the lucid source tree at rev 2945eab, 2026-11-14; OFL license
  # alongside). The family string is fc-scan-verified against that exact
  # file. Vendored so the lucid input could be retired with the Hyprland
  # stack — the font itself is session-independent.
  googleSansFlex = ./assets/fonts/GoogleSansFlex.ttf;
  googleSansFlexLicense = ./assets/fonts/OFL-GoogleSansFlex.txt;

  # --- Energy management (user spec 2026-11-08) ---------------------------
  # Noctalia's idle daemon is the only idle authority on this attr (no
  # swayidle/hypridle; logind keeps IdleAction=ignore and owns just the
  # lid). Targets: keyboard backlight off after 60 s idle or while locked,
  # lock at 5 min (5 s passwordless grace), screen off at 5.5 min,
  # suspend after 25 min on battery / 90 min on AC. The suspend→hibernate
  # second stage stays in hosts/yoga/yoga-s2h.nix (pure system-sleep hook,
  # session-independent — fires on this idle suspend like on any other).
  #
  # Every binary is an absolute store path: hook/idle shells inherit
  # noctalia.service's sparse environment (bare `bash` does not resolve in
  # systemd-spawned shells — 2026-11-07 lore).
  kbdLed = "platform::kbd_backlight"; # max_brightness 2 on this machine

  kbdOffScript = pkgs.writeShellScript "noctalia-kbd-off" ''
    export PATH=${pkgs.brightnessctl}/bin:${pkgs.coreutils}/bin
    # Zero the keyboard backlight, saving the current level first. Only a
    # non-zero level is saved so a double fire (idle timer + session-locked
    # hook on lock/suspend paths) never records 0 as the resting level.
    cur=$(brightnessctl -d ${kbdLed} get)
    [ "$cur" != "0" ] && printf '%s' "$cur" > "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/noctalia-kbd-bright"
    brightnessctl -d ${kbdLed} set 0
  '';

  kbdRestoreScript = pkgs.writeShellScript "noctalia-kbd-restore" ''
    export PATH=${config.programs.noctalia.package}/bin:${
      lib.makeBinPath [
        pkgs.brightnessctl
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }
    # Stay dark while locked — the session-unlocked hook re-runs this
    # after the password, so the light only returns with real presence.
    if noctalia msg status 2>/dev/null | grep -q '"locked"[[:space:]]*:[[:space:]]*true'; then
      exit 0
    fi
    saved=$(cat "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/noctalia-kbd-bright" 2>/dev/null || echo 1)
    brightnessctl -d ${kbdLed} set "$saved"
  '';

  suspendByPowerScript = pkgs.writeShellScript "noctalia-suspend-by-power" ''
    export PATH=${config.programs.noctalia.package}/bin:${pkgs.coreutils}/bin
    # Battery/AC idle-suspend split: 25 min on battery, 90 min on AC.
    # config-set persists exactly this one key into the state layer —
    # accepted trade-off; hooks.started re-derives it at every shell
    # start, so a stale value can never outlive a restart.
    ac=0
    for supply in /sys/class/power_supply/A*; do
      [ -r "$supply/online" ] && [ "$(cat "$supply/online")" = "1" ] && ac=1
    done
    if [ "$ac" = "1" ]; then
      noctalia msg config-set idle.behavior.suspend.timeout 5400
    else
      noctalia msg config-set idle.behavior.suspend.timeout 1500
    fi
  '';
in
{
  imports = [
    # Upstream HM module (options + noctalia.service + store symlinks);
    # defaults programs.noctalia.package to the flake input's own build
    # (binary-cached via noctalia.cachix.org, modules/core/nix.nix).
    inputs.noctalia.homeModules.default
  ];

  options.desktop.noctalia = {
    enable = lib.mkEnableOption ''
      Noctalia shell (bar, launcher, notifications, lock screen, idle, night
      light, clipboard, wallpaper renderer, polkit agent). Pair with
      features.desktop-niri on the NixOS side; the niri binds driving it
      live in home/niri.nix
    '';
  };

  config = lib.mkIf cfg.enable {
    # Lucid's Google Sans Flex for the shell UI (fc scans
    # ~/.local/share/fonts).
    xdg.dataFile."fonts/noctalia/GoogleSansFlex.ttf".source = googleSansFlex;
    xdg.dataFile."fonts/noctalia/OFL-GoogleSansFlex.txt".source = googleSansFlexLicense;

    programs.noctalia = {
      enable = true;
      # noctalia.service, PartOf/After/WantedBy wayland.systemd.target
      # (graphical-session.target — on niri the native session target that
      # niri.service pulls up itself, no uwsm in the chain).
      systemd.enable = true;

      settings = {
        shell = {
          # Lucid's type: rounded geometric sans (TTF above; features.fonts
          # keeps Inter as the fallback/GTK face).
          font_family = "Google Sans Flex";
          # German UI from the upstream catalog (assets/translations/de.json)
          # — zero patches, unlike lucid's 318-rule dictionary. Empty would
          # follow LANG (de_DE.UTF-8 system-wide); pinned so the shell
          # language never depends on the user-manager environment.
          lang = "de";
          # Anonymous startup ping — off.
          telemetry_enabled = false;
          # GUI-harvested 2026-11-15 (back to 0.8 — the 1.15 from the
          # 2026-11-06 round was re-tuned in the GUI).
          animation.speed = 0.8;
          # Noctalia's own polkit authentication agent — the niri attr
          # installs no hyprpolkitagent (modules/features/desktop-niri.nix).
          polkit_agent = true;
          # Direct fork instead of a transient systemd unit: the dbus
          # round trip was part of the sluggish dock click → window delay
          # (2026-11-06). The upstream tradeoff — launched apps dying with
          # a shell restart — is covered by the KillMode=process override
          # below (the unit restarts itself on every config-changing switch
          # via HM's X-Restart-Triggers, so this matters daily, not just for
          # manual restarts).
          # NOTE: the dock has NO launch feedback animation in v5.4.1
          # (source: no pending-launch visual state, only hover
          # magnification); the window is focused as soon as it maps
          # (tryFulfillPendingLaunchFocus).
          launch_apps_as_systemd_services = false;
          # Flat cards/popup borders off, panels anchored to the main bar
          # (user-tuned in Settings 2026-11-06, harvested). Type-to-launch
          # OFF + translucent settings window: GUI harvest 2026-11-15.
          card_borders = false;
          popup_borders = false;
          niri_overview_type_to_launch_enabled = false;
          settings_window_translucent = true;
          # Round avatar in the bar/control center — moved here from
          # [control_center] in v5.5.0 (GUI harvest 2026-11-15).
          circular_avatar = false;
          panel_anchor_bar = "main";
          # GUI-tuned (state layer, 2026-11-07) — harvested 2026-11-08:
          show_close_buttons = false;

          # Launcher (GUI harvest 2026-11-15): grid view, search field on
          # top, no nav labels, no session/settings buttons inside the
          # launcher, exchange-rate fetch off.
          launcher = {
            app_grid = true;
            fetch_exchange_rates = false;
            search_position = "top";
            show_navigation_labels = false;
            show_session_button = false;
            show_settings_button = false;
          };

          # Panel transparency: ONE global mode for every pop-out panel
          # (launcher, control center, clipboard) — three fixed steps,
          # no opacity slider. "glass" is the most transparent one
          # (panel 0.55, cards 0.75); "soft" reads nearly solid on the
          # cards (settled 2026-09-23 on the Hyprland trial).
          panel = {
            transparency_mode = "glass";
            # Inlet rows (launcher/clipboard list rows) sit directly on the
            # frosted panel instead of their own near-opaque card fill.
            list_item_background = false;
            # Control center floats free of the bar edge (GUI harvest).
            control_center_placement = "floating";
            # GUI harvest 2026-11-15: launcher opens bottom-center under
            # the cursor-side control-center click.
            launcher_position = "bottom_center";
            open_near_click_control_center = true;
          };

          # Corner hotspots + Alt-Tab switcher look (GUI harvest
          # 2026-11-07).
          screen_corners = {
            enabled = true;
            size = 14;
          };
          window_switcher = {
            mru = true;
            style = "compact";
          };
        };

        # Palette follows the wallpaper (user pick 2026-11-15, harvested
        # same day): source "wallpaper" + the M3 "content" quantization
        # scheme — Material-3 tonal extraction from the CURRENT wallpaper,
        # so changing the wallpaper re-themes the shell. mode "auto" flips
        # dark/light on the [location] sunrise/sunset schedule (same
        # machinery as night light; restored 2026-11-17 after the Nov 15
        # harvest accidentally baked in fixed dark). Inert fallbacks while
        # the wallpaper source is on: community palette "Tomorrow" (what
        # the GUI would apply if wallpaper sourcing went off) and builtin
        # "Nord" beneath it. shell_mode "follow" + sync_color_scheme are
        # the v5.5.0 defaults, spelled out because they carry the app
        # following: browsers/Electron/Qt read the freedesktop color-scheme
        # Noctalia writes. The GTK side is covered by the template applier
        # (ON since 2026-11-18, supersedes the 2026-11-08 GUI choice of
        # leaving it off — that stranded GTK4 apps dark behind an orphaned
        # Colloid gtk.css): every mode flip regenerates noctalia.css from
        # the wallpaper-M3 palette, injects @import url("noctalia.css")
        # into ~/.config/gtk-{3,4}.0/gtk.css and swaps gsettings gtk-theme
        # between adw-gtk3/-dark (apply.sh; the user-priority named colors
        # recolor libadwaita apps too). GTK4 apps restyle live; GTK3 apps
        # need a restart. btop stays OFF (home/terminal.nix owns it) and
        # the niri/kitty ids stay off regardless — they would rewrite
        # Nix-owned files. Caution: GUI toggles (theme mode, template
        # switches) write theme.* keys into
        # ~/.local/state/noctalia/settings.toml, which WINS per-key over
        # this baseline.
        theme = {
          mode = "auto";
          shell_mode = "follow";
          sync_color_scheme = true;
          source = "wallpaper";
          builtin = "Nord";
          pure_black_dark = false;
          community_palette = "Tomorrow";
          wallpaper_scheme = "m3-content";

          templates = {
            enable_builtin_templates = true;
            builtin_ids = [
              "gtk3"
              "gtk4"
            ];
          };
        };

        # Blurred niri overview: Noctalia's dedicated backdrop layer, which
        # the `^noctalia-backdrop` layer-rule in home/niri.nix places within
        # niri's overview backdrop (upstream niri recipe, option 1).
        backdrop.enabled = true;

        # Bar: ONE top bar surface in capsule mode with three explicit
        # capsule_group definitions (three named bars can't do this —
        # layer-shell would stack them vertically on the top edge).
        # Geometry + frost from the GUI tuning rounds, harvested
        # 2026-11-08 (supersedes the 2026-11-06 transparent-strip look):
        # the strip itself now carries the frost (background_opacity 0.59,
        # client blur regions — see the bar layer-rule note in
        # home/niri.nix) while the pill fills sit at opacity 0 on top of
        # it. radius 17 clamps to half the 28px thickness in the renderer
        # (full-round ends); the clock pill centers, left/right pills hug
        # their margins.
        bar.main = {
          position = "top";
          start = [
            "workspaces"
            "tray"
          ];
          center = [ "clock" ];
          # GUI harvest 2026-11-15: bluetooth + control-center joined the
          # end widgets. (The right capsule_group below still lists the
          # original four — that is exactly what the live layer carried.)
          end = [
            "notifications"
            "bluetooth"
            "network"
            "volume"
            "battery"
            "control-center"
          ];
          thickness = 28;
          margin_edge = 5;
          margin_ends = 20;
          padding = 10;
          # GUI harvest 2026-11-15 (was 1.05 from the 11-08 harvest).
          scale = 1.1;
          font_scale = 0.9;
          radius = 17;
          shadow = true;
          contact_shadow = true;
          background_opacity = 0.59; # the strip carries the frost now
          capsule = true;
          capsule_opacity = 0.0; # pill fills off — strip frost only
          capsule_padding = 3;
          capsule_thickness = 1.0;
          capsule_border_width = 0.0;
          capsule_group = [
            {
              id = "left";
              members = [
                "workspaces"
                "tray"
              ];
            }
            {
              id = "center";
              members = [ "clock" ];
            }
            {
              id = "right";
              members = [
                "notifications"
                "network"
                "volume"
                "battery"
              ];
            }
          ];
        };

        # Workspaces widget (left): minimal style — slim pills instead of
        # the wide numbered chips that overflowed the pill — and empty
        # workspaces hidden so only occupied/focused ones render.
        # Widget knobs from the GUI rounds (harvested 2026-11-08): slim
        # workspace pills, label-less network/volume icons, volume scale.
        widget = {
          workspaces = {
            style = "minimal";
            hide_when_empty = true;
          };
          network.show_label = false;
          volume = {
            mute_color = "on_hover";
            scale = 0.9;
            show_label = false;
          };
          # GUI harvest 2026-11-15: bluetooth widget hides with the adapter
          # off; control-center uses the "assembly" glyph.
          bluetooth.hide_when_adapter_off = true;
          control-center.glyph = "assembly";
        };

        # Desktop widget cards (calendar/clock/weather on the wallpaper):
        # GUI-off since the tuning rounds (harvested 2026-11-08).
        desktop_widgets.enabled = false;

        # Runtime knobs harvested 2026-11-08: short notification history
        # (privacy), overlay layer, two at a time; slow disk polling — the
        # monitor card is glanced at, not watched.
        notification = {
          history_retention_hours = 3;
          layer = "overlay";
          max_visible = 2;
        };
        system.monitor = {
          disk_poll_seconds = 60;
          gpu_poll_seconds = 10;
        };

        # GUI harvest 2026-11-15 (state-layer keys that had no declarative
        # counterpart — recorded so the state layer can stay empty;
        # weather.refresh_minutes moved into the weather block below):
        audio.enable_sounds = false;
        battery.warning_threshold = 15;
        bluetooth.connection_notifications = true;

        # Control center (GUI harvest 2026-11-15): no avatar chrome, audio
        # tab hidden, no sidebar, week numbers in the calendar, and the
        # five-button shortcut grid. circular_avatar lives in [shell] as
        # of v5.5.0 (upstream migration; kept in the shell block above).
        control_center = {
          hidden_tabs = [ "audio" ];
          show_avatar_border = false;
          show_session_button = false;
          sidebar = "none";
          calendar.show_week_numbers = true;
          shortcuts = [
            { type = "wifi"; }
            { type = "bluetooth"; }
            { type = "caffeine"; }
            { type = "nightlight"; }
            { type = "notification"; }
          ];
        };

        # Bottom-center dock island: lucid geometry from the dux-shell port
        # (42px icons, hover magnification). Hiding = the user-picked
        # smart_auto_hide mode (visible only when the active workspace is
        # empty or the overview is open; when hidden the panel slides off
        # and Noctalia clears its blur — dock_instance.cpp clears
        # compositor blur independently of scene opacity). reserve_space
        # stays off so it floats over content when visible.
        dock = {
          # Disabled by live choice (harvested 2026-11-07: the state layer
          # has had it off since the tuning rounds and wins over this file).
          # Geometry kept so a GUI re-enable gets the tuned lucid look back.
          enabled = false;
          position = "bottom";
          icon_size = 42;
          background_opacity = 0.55;
          concave_edge_corners = false;
          auto_hide = false;
          smart_auto_hide = true;
          reserve_space = false;
          magnification = true;
          show_running = true;
          show_dots = true;
          pinned = [
            "foot"
            "firefox"
            "org.gnome.Nautilus"
          ];
        };

        wallpaper = {
          # Noctalia renders wallpapers itself (no awww/swww on this attr).
          # Stable user paths only — a /nix/store path here dies at GC and
          # blacks out the desktop (upstream issue #4425).
          directory = wallpaperDir;
          default.path = "${wallpaperDir}/golden-mist-valley.jpg";
          # Same fade-only policy as the lock screen (default list includes
          # wipes/discs/stripes/…).
          transition = [ "fade" ];
          transition_duration = 800;
        };

        nightlight = {
          enabled = true;
          # Schedule comes from the location service below.
          temperature_night = 4500;
        };

        location = {
          # Sun-based night light schedule. Fixed coordinates (darkman
          # parity, home/theme.nix) instead of IP auto-locate —
          # deterministic, no third-party lookup. Longitude = the user's
          # real meridian (GUI harvest 2026-11-15; latitude unchanged).
          latitude = 52.52;
          longitude = 8.524;
        };

        # Weather (Open-Meteo, no API key): feeds the lockscreen weather
        # line below + a control-center weather tab; the bar stays
        # untouched. Coordinates come from [location] above. refresh 40 =
        # the GUI value (harvested 2026-11-15). effects = the animated
        # precipitation shader in the control-center tab only — the
        # lockscreen widget ignores it.
        weather = {
          enabled = true;
          unit = "celsius";
          refresh_minutes = 40;
          effects = true;
        };

        # Energy timeline (user spec 2026-11-08), all inhibitor-aware so
        # video playback holds the timers off:
        #   60 s    keyboard backlight off (custom action; restored on
        #           activity — but stays dark while locked, hooks below)
        #   5 min   lock (5 s passwordless grace — lockscreen below)
        #   5.5 min screen off (DPMS)
        #   25 min  suspend on battery / 90 min on AC (power hooks flip
        #           the suspend timeout; see suspendByPowerScript)
        # pre_action_fade_seconds = 0: the 2 s fullscreen "Idle Dim" fires
        # before EVERY behavior — live-probed 2026-11-08, custom actions
        # included — which would dim the screen at the 60 s keyboard-off.
        # Lock/screen-off fire silently instead (their own transitions
        # remain).
        # The suspend→hibernate second stage is NOT here:
        # hosts/yoga/yoga-s2h.nix catches every suspend (idle, lid,
        # manual) as a pure system-sleep hook and RTC-wakes to hibernate
        # 2 h later, battery only.
        idle = {
          pre_action_fade_seconds = 0;
          behavior_order = [
            "kbd-off"
            "lock"
            "screen-off"
            "suspend"
          ];
          behavior = {
            "kbd-off" = {
              enabled = true;
              timeout = 60;
              action = "custom";
              command = "${kbdOffScript}";
              resume_command = "${kbdRestoreScript}";
            };
            "lock" = {
              enabled = true;
              timeout = 300;
              action = "lock";
            };
            "screen-off" = {
              enabled = true;
              timeout = 330;
              action = "screen_off";
            };
            "suspend" = {
              # lock_and_suspend (GUI-harvested action): locks right
              # before suspending. Hibernate stays parked on this
              # firmware — the s2h hook handles the second stage.
              enabled = true;
              # Battery baseline; suspendByPowerScript rewrites this one
              # key to 5400 on AC via the hooks below.
              timeout = 1500;
              action = "lock_and_suspend";
            };
          };
        };

        # Event hooks (18 kinds exist; TOML keys are snake_case). All
        # power events call the same probe so the decision is derived,
        # not trusted from the event: charging/discharging re-set the
        # suspend timeout live, started re-derives it at every shell
        # start (also self-heals a stale runtime value after a restart).
        # Lock/unlock drive the keyboard backlight alongside the idle
        # timer (suspend paths lock first via lock_before_suspend, so
        # the light is always dark before the machine sleeps).
        hooks = {
          started = [ "${suspendByPowerScript}" ];
          battery_charging = [ "${suspendByPowerScript}" ];
          battery_discharging = [ "${suspendByPowerScript}" ];
          session_locked = [ "${kbdOffScript}" ];
          session_unlocked = [ "${kbdRestoreScript}" ];
        };

        # Lock screen: big digital clock up top, a weather line beneath it
        # and a small frosted password capsule below-center (sleek round
        # 2026-11-06; round 2 on 2026-11-07 softened it: hard clock shadow
        # off, on_surface ink, box-fit clock, capsule lifted to cy 640
        # with pill input; round 4 on 2026-11-15 grew the clock to ~110px
        # and added the weather line). No per-widget scale or text widget
        # exists for lockscreen
        # widgets in v5.4.1 (validator warns `scale: unknown setting`;
        # clock font stays hard-fixed at 4x body, so a small date line is
        # not expressible — size only via the entry's box-fit) — geometry
        # and style only. The geometry keys are editor-owned: the
        # widget editor re-saves them into the state layer, which wins over
        # this baseline — fine-tune live, harvest back here. Logical panel:
        # eDP-1 3072x1920 @ scale 2 => 1536x960, center cx=768. If a lock
        # screen ever refuses the password: Ctrl+Alt+F2 →
        # `systemctl --user stop noctalia`.
        lockscreen_widgets = {
          enabled = true;
          # Schema 2 of the widget editor (GUI harvest 2026-11-15): the
          # editor carries its own canvas grid + per-widget placement
          # metadata (canvas = 1536x960 logical panel, rotation unused).
          # Recorded verbatim so the editor finds its state after a strip.
          schema_version = 2;
          grid = {
            cell_size = 16;
            major_interval = 4;
            visible = true;
          };
          widget_order = [
            "lockscreen-widget-0000000000000001"
            "lockscreen-widget-0000000000000002"
            "lockscreen-login-box@eDP-1"
          ];
          widget = {
            "lockscreen-widget-0000000000000001" = {
              type = "clock";
              output = "eDP-1";
              cx = 768.0;
              cy = 300.0;
              placement_height = 960.0;
              placement_width = 1536.0;
              rotation = 0.0;
              # Explicit box => the host setBox()es the widget and layout
              # scales the content aspect-preserved to fill it (height is
              # the binding constraint): natural 4x-body digits (~56px)
              # render at ~110px (round 4 2026-11-15: 360x120 → 440x146).
              # The font size itself is hard-fixed — this box-fit is the
              # only size control.
              box_width = 440.0;
              box_height = 146.0;
              settings = {
                clock_style = "digital";
                format = "{:%H:%M}";
                center_text = true;
                # The digital label shadow is a HARD offset (Shadow role at
                # 0.6 alpha, +1.5/+1.5px; no blur knob exists on
                # Label::setShadow) — in light mode it reads as a dark
                # "border" around the digits. Off for the soft look.
                shadow = false;
                # on_surface: the brightest theme-following ink. Round 2's
                # on_surface_variant read too muted; role tokens carry no
                # alpha knob (hex would drop theme-following), so this is
                # the only brightness step between muted and this.
                color = "on_surface";
                # EXPLICIT zero: the controller normalizes a MISSING
                # background_opacity to 0.8 and draws a card plate behind
                # the clock (2026-09-23 source-proven).
                background_opacity = 0.0;
                # The invisible plate still insets the box-fit content
                # area by its padding (default 10px each side) — zero it
                # so the full 440x146 box reaches the digits.
                background_padding = 0.0;
              };
            };
            # Weather line (round 4 2026-11-15): current conditions
            # between clock and capsule, fed by the [weather] service.
            # Same plate-less treatment as the clock (explicit 0.0
            # opacity — a missing key normalizes to the 0.8 card plate;
            # padding 0 so the plate can't inset the box fit) and shadow
            # off (the label shadow is a hard offset — the same
            # light-mode "border" the clock shed in round 2). Ink follows
            # the theme via the default on_surface color. Current
            # conditions only — the 6-day forecast lives in the
            # control-center weather tab.
            "lockscreen-widget-0000000000000002" = {
              type = "weather";
              output = "eDP-1";
              cx = 768.0;
              # Vertical ladder: clock 227-373, weather 405-465, capsule
              # 605-675.
              cy = 435.0;
              placement_height = 960.0;
              placement_width = 1536.0;
              rotation = 0.0;
              box_width = 360.0;
              box_height = 60.0;
              settings = {
                shadow = false;
                show_forecast = false;
                background_opacity = 0.0;
                background_padding = 0.0;
              };
            };
            "lockscreen-login-box@eDP-1" = {
              type = "login_box";
              output = "eDP-1";
              cx = 768.0;
              # Two-thirds down the panel: big clock above, capsule
              # anchored lower-center (round 2 2026-11-07, was 778).
              cy = 640.0;
              placement_height = 960.0;
              placement_width = 1536.0;
              rotation = 0.0;
              # Compact layout clamps to 240..400 but the 400 cap only
              # applies when box_width is 0 — a lingering 810 from the
              # regular layout stays 810 wide, so pin it. Height: the
              # editor re-saved 70 px (GUI harvest; 0 = auto-fit).
              box_width = 400.0;
              box_height = 70.0;
              settings = {
                # compact = the slim password row; power/reboot live in
                # the session menu (Mod+P). Enter unlocks, so no login
                # button; the idle "ready" hint is off but errors and the
                # caps-lock warning still render (gated separately in the
                # source).
                layout = "compact";
                # Frosted + muted glass (round 3): base "surface" is the
                # most neutral role (surface_container read tinted), and
                # the low opacity lets the wallpaper frost through. The
                # panel opacity also scales the hard-coded 1px
                # OutlineVariant border alpha in the source.
                background_color = "surface";
                background_opacity = 0.30;
                background_radius = 18.0;
                # Pill input, translucent fill so the frost shows through
                # (0.9 read as a solid, colorful pill).
                input_radius = 20.0;
                input_opacity = 0.55;
                center_password_text = true;
                show_login_button = false;
                show_unlock_hint = false;
                show_caps_lock = true;
                show_weather = false;
                show_media = false;
                # GUI harvest 2026-11-07 (reveal eye, layout chip,
                # session buttons):
                show_password_reveal = true;
                show_keyboard_layout = true;
                show_session_buttons = true;
              };
            };
          };
        };

        # Soft zoom reveal on lock/unlock (round 4 2026-11-15, user pick
        # over fade/disc): the whole screen scales gently into the frosted
        # wallpaper. One transition covers BOTH directions (separate
        # lock/unlock effects are an open upstream PR) — the pool syntax
        # means a random pick per event, hence exactly one entry. 800ms
        # instead of the 1500ms default: present, not a show. The schema
        # default list (wipe/disc/stripes/honeycomb/vortex/pixel/…) reads
        # gimmicky next to the minimal frosted look; the wallpaper gets
        # the same restraint below (fade@800).
        #
        # dnd (new in v5.5.0): silence notifications while locked. They
        # never RENDER on the lock surface (ext-session-lock keeps
        # everything below it) but their sounds played invisibly — with
        # dnd they go straight to history and greet you in the control
        # center after unlock. Restored automatically on unlock.
        #
        # The lock is an ext-session-lock surface: niri layer-rules cannot
        # match it and it publishes no blur regions, so this client-side
        # frost (self-rendered wallpaper blur radius = intensity * 40px,
        # 3 passes, over a theme Surface tint) is the ONLY frost control.
        # Deeper than the 0.5/0.3 defaults so the clock and login capsule
        # pop (sleek round 2026-11-06). edge_smoothness feathers the zoom
        # edge (0.3 default → 0.6 soft).
        lockscreen = {
          transition = [ "zoom" ];
          transition_duration = 800;
          edge_smoothness = 0.6;
          dnd = true;
          blur_intensity = 0.7;
          tint_intensity = 0.35;
          # 5 s passwordless grace right after lock (user spec
          # 2026-11-08: unlockable without typing for 5 s after the lock
          # lands).
          grace_period_seconds = 5;
          fingerprint = false; # GUI harvest; the sensor stays unused
          # Lock before (lid/logind) sleeps. Authenticates through PAM
          # service "login" (gnome-keyring unlock wired in
          # desktop-niri.nix).
          lock_before_suspend = true;
        };
      };
    };

    # Launched apps are direct forks (launch_apps_as_systemd_services =
    # false), so they live in this unit's cgroup — and HM's
    # X-Restart-Triggers restart the unit on every config change. With the
    # default control-group KillMode, each switch killed every app started
    # from the launcher/dock (agent sessions included). process = SIGTERM
    # to the shell only; the apps survive.
    systemd.user.services.noctalia.Service.KillMode = "process";
  };
}
