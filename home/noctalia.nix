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
  # with `noctalia config export merged`.
  wallpaperDir = "${config.home.homeDirectory}/Bilder/wallpapers";

  # Google Sans Flex — lucid's UI font, borrowed from the lucid flake input
  # (flake = false source tree; same file the dux-shell branch ships DMS).
  # The family string is fc-scan-verified against that exact file.
  # Coupling note: removing the lucid input while noctalia is enabled breaks
  # eval — vendor the TTF into the repo first if lucid ever goes away.
  googleSansFlex = "${inputs.lucid}/assets/fonts/GoogleSansFlex.ttf";
  googleSansFlexLicense = "${inputs.lucid}/assets/fonts/OFL-GoogleSansFlex.txt";

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
          # User-tuned 2026-11-06 (was 0.8 from the pacing round — 1.15
          # reads right next to niri's springs on this panel).
          animation.speed = 1.15;
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
          # Flat cards/popup borders off, type-to-launch in the niri
          # overview, panels anchored to the main bar (user-tuned in
          # Settings 2026-11-06, harvested).
          card_borders = false;
          popup_borders = false;
          niri_overview_type_to_launch_enabled = true;
          panel_anchor_bar = "main";
          # GUI-tuned (state layer, 2026-11-07) — harvested 2026-11-08:
          show_close_buttons = false;

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

        # Rosé Pine palette (user pick 2026-11-06), auto light/dark by sun
        # schedule (location below); the community "Rose Pine Alt" variant
        # + faithful wallpaper extraction won the GUI tuning rounds
        # (harvested 2026-11-08). The template applier stays OFF (GUI
        # choice, harvested): GTK theming is owned by home/theme.nix
        # (adw-gtk3) and btop by home/terminal.nix — the ids stay listed
        # only so a GUI re-enable finds its tuned set.
        theme = {
          mode = "auto";
          source = "builtin";
          builtin = "Rosé Pine";
          pure_black_dark = false;
          community_palette = "Rose Pine Alt";
          wallpaper_scheme = "faithful";

          templates = {
            enable_builtin_templates = false;
            builtin_ids = [
              "btop"
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
          end = [
            "notifications"
            "network"
            "volume"
            "battery"
          ];
          thickness = 28;
          margin_edge = 5;
          margin_ends = 20;
          padding = 10;
          scale = 1.05;
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
          # Sun-based night light + theme auto schedule. Fixed coordinates
          # (darkman parity, home/theme.nix) instead of IP auto-locate —
          # deterministic, no third-party lookup.
          latitude = 52.52;
          longitude = 13.40;
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

        # Lock screen: big digital clock up top, a small frosted password
        # capsule below-center (sleek round 2026-11-06; round 2 on
        # 2026-11-07 softened it: hard clock shadow off, on_surface_variant
        # ink, box-fit clock ~90px, capsule lifted to cy 640 with pill
        # input). No per-widget scale or text widget exists for lockscreen
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
          widget_order = [
            "lockscreen-widget-0000000000000001"
            "lockscreen-login-box@eDP-1"
          ];
          widget = {
            "lockscreen-widget-0000000000000001" = {
              type = "clock";
              output = "eDP-1";
              cx = 768.0;
              cy = 300.0;
              # Explicit box => the host setBox()es the widget and layout
              # scales the content aspect-preserved to fill it (height is
              # the binding constraint): natural 4x-body digits (~56px)
              # render at ~90px. The font size itself is hard-fixed — this
              # box-fit is the only size control.
              box_width = 360.0;
              box_height = 120.0;
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
                # so the full 360x120 box reaches the digits.
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

        # Clean quick crossfade on lock/unlock — the schema default picks
        # from a fancy transition list (wipe/disc/stripes/honeycomb/vortex/
        # pixel/…) at 1500ms, which reads gimmicky next to the minimal
        # frosted look. Wallpaper changes get the same treatment below.
        #
        # The lock is an ext-session-lock surface: niri layer-rules cannot
        # match it and it publishes no blur regions, so this client-side
        # frost (self-rendered wallpaper blur radius = intensity * 40px,
        # 3 passes, over a theme Surface tint) is the ONLY frost control.
        # Deeper than the 0.5/0.3 defaults so the clock and login capsule
        # pop (sleek round 2026-11-06).
        lockscreen = {
          transition = [ "fade" ];
          transition_duration = 300;
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
