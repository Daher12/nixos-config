{
  config,
  lib,
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
          };
        };

        # Rosé Pine builtin palette (user pick 2026-11-06), auto light/dark
        # by sun schedule (location below). The gtk3/gtk4 templates apply it
        # to GTK apps (settings.ini — owned by the templates here, see the
        # activation + theme.nix handover; Firefox/ZCode follow GTK), btop
        # gets a generated theme. Deliberately NOT enabled: "niri" (would
        # rewrite the Nix-owned config.kdl) and "kitty" (kitty.conf is a
        # Nix store symlink — terminals keep their static theme).
        theme = {
          mode = "auto";
          source = "builtin";
          builtin = "Rosé Pine";
          pure_black_dark = false;

          templates = {
            enable_builtin_templates = true;
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

        # Bar: THREE frosted pills (user proposal 2026-11-06 — the modern
        # segmented look). Mechanism: ONE top bar surface in capsule mode
        # with three explicit capsule_group definitions (members list); the
        # strip itself stays fully transparent (background_opacity 0, no
        # forced blur) and each pill frosts via its own client blur region —
        # see the bar layer-rule note in home/niri.nix. Three named bars
        # can't do this: layer-shell would stack them vertically on the
        # top edge. Each pill keeps full-radius capsule ends; the clock
        # pill centers, left/right pills hug their margins.
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
          thickness = 34;
          margin_edge = 10;
          margin_ends = 24;
          radius = 17;
          shadow = true;
          contact_shadow = true;
          background_opacity = 0.0; # transparent strip — the pills carry it
          capsule = true;
          capsule_opacity = 0.68; # user-tuned
          capsule_padding = 6;
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
        widget.workspaces = {
          style = "minimal";
          hide_when_empty = true;
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
            "kitty"
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

        # Single global timeout set (no battery/AC split): DPMS off / lock /
        # suspend at 3/5/15 min (user spec 2026-09-22). Inhibitor-aware, so
        # video playback holds the timers off. The example config ships the
        # behaviors disabled — `enabled` must be set explicitly.
        idle = {
          behavior_order = [
            "screen-off"
            "lock"
            "suspend"
          ];
          behavior = {
            "screen-off" = {
              enabled = true;
              timeout = 180;
              action = "screen_off";
            };
            "lock" = {
              enabled = true;
              timeout = 300;
              action = "lock";
            };
            "suspend" = {
              # Plain suspend; hibernate stays parked on this firmware.
              # Noctalia also locks through its logind sleep monitor right
              # before any suspend (lock_before_suspend), so the lock
              # screen is the wake gate regardless of the idle path.
              enabled = true;
              timeout = 900;
              action = "suspend";
            };
          };
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
                # Softer theme-following ink instead of the on_surface
                # default; follows light/dark automatically.
                color = "on_surface_variant";
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
              # regular layout stays 810 wide, so pin it. Height 0 =
              # auto-fit the single password row.
              box_width = 400.0;
              box_height = 0.0;
              settings = {
                # compact = password row only; the session buttons do not
                # exist in this layout (power/reboot live in the session
                # menu, Mod+P). Enter unlocks, so no login button; the idle
                # "ready" hint is off but errors and the caps-lock warning
                # still render (gated separately in the source).
                layout = "compact";
                # Softer glass (round 2): panel opacity 0.45 -> 0.35 also
                # softens the hard-coded 1px OutlineVariant border — its
                # alpha comes from the panel opacity in the source.
                background_opacity = 0.35;
                background_radius = 18.0;
                # Pill-shaped input at the schema's max, slightly
                # translucent fill.
                input_radius = 20.0;
                input_opacity = 0.9;
                center_password_text = true;
                show_login_button = false;
                show_unlock_hint = false;
                show_caps_lock = true;
                show_weather = false;
                show_media = false;
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
