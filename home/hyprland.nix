{
  config,
  lib,
  ...
}:

let
  cfg = config.desktop.hyprland;

  # Hyprland 0.55+ Lua config. The Lucid shell (home/lucid.nix) provides
  # bar/launcher/lock/notifications/idle — its keybinds, surface rules and
  # glass layers are loaded from the modules required near the end of this
  # file.
  monitorLua = m: ''
    hl.monitor({
        output   = "${m.output}",
        mode     = "${m.mode}",
        position = "${m.position}",
        scale    = "${m.scale}",
    })
  '';

  monitorsLua =
    if cfg.monitors == [ ] then
      monitorLua {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      }
    else
      lib.concatMapStrings monitorLua cfg.monitors;

  # Lid switch: internal panel off when closed, restored when opened (docked
  # use; logind still suspends per the laptop profile). Hyprland 0.55 moved
  # monitors into the Lua config parser, where `hyprctl keyword monitor ...`
  # is refused ("keyword can't work with non-legacy parsers") while still
  # exiting 0 — a silent no-op. The runtime path is `hyprctl eval` on
  # hl.monitor. Re-opening needs `hyprctl reload`: eval accepts
  # disabled=false but the panel stays off (verified 0.55.4); only a reload
  # re-applies the config's hl.monitor block and re-enables it.
  #
  # The close bind only disables the panel while another monitor is enabled:
  # an ext-session-lock lock request arriving with zero enabled outputs
  # segfaults Hyprland 0.55.4 (onNewSessionLock → setGrab →
  # isVisibleNotCovered; crash 2026-10-13,
  # ~/.cache/hyprland/hyprlandCrashReport166486.txt). hypridle's
  # before-sleep lock races the lid bind, quickshell gets "no outputs" and
  # the compositor dies one second before suspend entry. Solo lid-close
  # therefore leaves eDP-1 logically enabled — suspend blanks it anyway.
  lidSwitchLua =
    if cfg.monitors == [ ] then
      ""
    else
      let
        m = builtins.head cfg.monitors;
      in
      ''
        hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("if [ \"$(hyprctl monitors | grep -c '^Monitor ')\" -gt 1 ]; then hyprctl eval 'hl.monitor({output=\"${m.output}\", disabled=true})'; fi"), { locked = true })
        hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
      '';

  # Session-shell IPC verbs behind the muscle-memory binds below: lucid and
  # DMS expose different surfaces for the same actions (verified against
  # lucid's IPC usage and DMSShellIPC.qml / duxlabs.dev docs, 2026-11-05):
  # launcher→spotlight, power popout→powermenu, workspace overview→
  # Hyprland's own overview on DMS (dms ipc call hypr), notifications panel
  # → the dash's notifications tab; clipboard, settings and lock have
  # direct equivalents.
  shellIpc =
    if config.desktop.dms.enable then
      {
        launcher = "dms ipc call spotlight toggle";
        power = "dms ipc call powermenu toggle";
        lock = "dms ipc call lock lock";
        overview = "dms ipc call hypr toggleOverview";
        clipboard = "dms ipc call clipboard toggle";
        notifs = "dms ipc call dash toggle notifications";
        settings = "dms ipc call settings toggle";
      }
    else
      {
        launcher = "qs ipc call launcher toggle";
        power = "qs ipc call launcher power";
        lock = "qs ipc call lock lock";
        overview = "qs ipc call workspaces toggle";
        clipboard = "qs ipc call launcher clipboard";
        notifs = "qs ipc call notifs toggle";
        settings = "qs ipc call settings toggle";
      };

  # Binds lucid's keybinds.json owns on the lucid path (loaded via
  # modules.binds): workspace focus/move + XF86 media/brightness. DMS has
  # no loader for our Lua config, so they are bound here, DMS-only.
  # Brightness keeps the 10% linear steps the user chose (2026-11-01).
  # Screenshots are deliberately NOT ported: DMS ships its own screenshot
  # tooling (dms screenshot + Settings > Keyboard shortcuts) — bind live
  # during the evaluation, then harvest into this block.
  dmsOnlyBindsLua = ''
    -- Workspaces 1-10 (lucid keybinds.json parity): SUPER+N focus,
    -- SUPER+SHIFT+N move. ALT+N (move) above stays as a harmless duplicate.
    for i = 1, 10 do
        hl.bind(mainMod .. " + " .. i % 10, hl.dsp.exec_cmd("hyprctl dispatch workspace " .. i % 10))
        hl.bind(mainMod .. " + SHIFT + " .. i % 10, hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace " .. i % 10))
    end

    -- XF86 media/brightness keys (keybinds.json parity)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"))
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"))
    hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))
    hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
    hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"))
    hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"))
    hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -n2 set 10%+"))
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -n2 set 10%-"))
  '';

  hyprlandLua = ''
    -- Generated by home-manager from home/hyprland.nix — do not edit.
    -- API reference: hyprland 0.55 Lua config (share/hypr/hyprland.lua in the
    -- hyprland package, wiki.hypr.land Configuring section).

    local terminal    = "${cfg.terminal}"
    local fileManager = "${cfg.fileManager}"
    local browser     = "${cfg.browser}"
    local mainMod     = "SUPER"

    -- Monitors
    ${monitorsLua}

    -- Lucid v1.20 Settings-driven modules. Required BEFORE anything this
    -- file sets (upstream's contract, documented in settings.lua: what the
    -- user config sets afterwards wins): settings.lua applies whatever
    -- Lucid Settings > Windows/Input writes to
    -- ~/.config/hypr/lucid-settings.lua (data-only file, loaded with an
    -- empty environment), and lucid-look.lua fills the blur/shadow
    -- defaults the shell's own surfaces sample — every option in the
    -- hl.config blocks below overrides them. pcall keeps the compositor
    -- alive if a module is mid-sync or missing.
    pcall(require, "modules.settings")
    pcall(require, "modules.lucid-look")

    -- Look & feel. Geometry/shadow/blur/motion are owned here (Nix);
    -- border colors are the static Nord pair below — Lucid's matugen only
    -- colors the shell and GTK, never the compositor.
    hl.config({
        general = {
            gaps_in  = 8,
            gaps_out = 12,
            border_size = 1,
            col = {
                active_border = "rgba(7d7eaaff)",
                inactive_border = "rgba(4c566aaa)",
            },
            resize_on_border = false,
            allow_tearing = false,
            layout = "dwindle",
        },
        decoration = {
            -- 16 matches Lucid's Material 3 corner rounding
            -- so windows and shell popouts share one radius
            rounding       = 16,
            rounding_power = 2,
            active_opacity   = 1.0,
            -- 0.96 keeps unfocused windows distinguishable without the
            -- washed-out gray look stronger dimming produces
            inactive_opacity = 0.96,
            shadow = {
                enabled = true,
                range = 24,
                render_power = 3,
            },
            -- Frosted glass (lucid Settings > General > Glass): the slider
            -- (state: ~/.config/quickshell/lucidbar/blur.json) only sets
            -- surface translucency + ext-background-effect-v1 blur regions —
            -- Hyprland renders the frost from this block. noise and
            -- ignore_opacity pin lucid-look.lua's values so the recipe no
            -- longer depends on that module surviving a pin bump.
            blur = {
                enabled        = true,
                size           = 10,
                passes         = 2,
                vibrancy       = 0.2,
                noise          = 0.04,
                ignore_opacity = true,
            },
        },
        animations = { enabled = true },
    })

    -- Material 3 motion using Caelestia's curve set (2026-10-10 polish
    -- round): decelerating entrances, faster accelerating exits, snappy
    -- border/fade leaves (they used to inherit the sluggish global default).
    -- Per-leaf names verified against the 0.55.4 animation registry
    -- (`hyprctl animations`). The shell's own QML durations are tuned
    -- separately via lucid's motion prefs (lucidSync migration:
    -- motionScale 0.85, barMotionScale 1.0).
    hl.curve("decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
    hl.curve("accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
    hl.curve("std", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
    hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5, bezier = "decel", style = "slide" })
    hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "accel", style = "slide" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "std", style = "slide" })
    -- layers keep the fade style (lucid's popouts fade in QML too — a slide
    -- here would fight it); the faster speeds cut the double-fade mush.
    hl.animation({ leaf = "layersIn",  enabled = true, speed = 5, bezier = "decel", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "accel", style = "fade" })
    hl.animation({ leaf = "fadeIn",  enabled = true, speed = 6, bezier = "std" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 6, bezier = "std" })
    hl.animation({ leaf = "border",  enabled = true, speed = 6, bezier = "std" })
    hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "std", style = "slide" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "decel", style = "slidefadevert 15%" })

    -- dwindle.pseudotile no longer exists in the 0.55 Lua config; pseudo is a
    -- per-window toggle via hl.dsp.window.pseudo() now.
    hl.config({
        dwindle = {
            preserve_split = true,
        },
    })

    hl.config({
        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            disable_hyprland_guiutils_check = true,
        },
        xwayland = {
            force_zero_scaling = true,
        },
    })

    hl.config({
        input = {
            kb_layout  = "de,us",
            kb_variant = "nodeadkeys,",
            kb_options = "grp:alt_shift_toggle",
            follow_mouse = 1,
            sensitivity = 0,
            touchpad = { natural_scroll = true },
        },
    })

    -- GNOME-style touchpad gestures (0.55 gesture system): the horizontal
    -- 3-finger swipe is Hyprland's 1:1 workspace swipe (workspaces follow
    -- the fingers, like GNOME's shell); 3-finger up opens the session
    -- shell's workspace overview (lucid: workspaces panel; DMS: Hyprland's
    -- own overview), standing in for GNOME's Activities overview (same IPC
    -- as the SUPER+TAB bind below).
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    -- Exec-on-gesture takes a lambda (action is a string naming a builtin
    -- action or a Lua function — NOT a dispatcher object like hl.dsp.exec_cmd
    -- returns for hl.bind).
    hl.gesture({
        fingers = 3,
        direction = "up",
        action = function()
            hl.exec_cmd("${shellIpc.overview}")
        end,
    })

    -- Keybinds: the DMS-era layout the user asked to keep (2026-09-23),
    -- mapped onto the session shell's IPC surface (shellIpc in the Nix let
    -- block). On the lucid path everything not bound here lives in
    -- ~/.config/lucid/keybinds.json (workspaces 1-10, arrows/split, mouse,
    -- XF86 media/brightness, screenshots, tap-Super launcher) — loaded by
    -- modules.binds below; on the DMS path the dms-only block below carries
    -- the workspace + XF86 keys instead (edit via Lucid Settings >
    -- Keybinds / DMS Settings > Shortcuts respectively). Entries the json
    -- used to bind were disabled in its seed where they collided with this
    -- set (see home/lucid.nix).
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
    hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

    -- ALT + [0-9]: move the active window to workspace N (the dispatcher
    -- lucid's ws-move entries use). Lucid's keybinds.json owns SUPER+N
    -- (focus) and SUPER+SHIFT+N (move); bare ALT was unused, so this
    -- duplicates neither — the layout switch is ALT+SHIFT (grp:alt_shift_toggle).
    for i = 1, 10 do
        hl.bind("ALT + " .. i % 10, hl.dsp.window.move({ workspace = i }))
    end

    ${lib.optionalString config.desktop.dms.enable dmsOnlyBindsLua}

    -- Apps & shell surfaces (session-shell IPC — see shellIpc in the Nix
    -- let block)
    hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal))
    hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager))
    hl.bind(mainMod .. " + F1",        hl.dsp.exec_cmd(browser))
    hl.bind(mainMod .. " + R",     hl.dsp.exec_cmd("${shellIpc.launcher}"))
    hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("${shellIpc.power}"))
    hl.bind(mainMod .. " + L",     hl.dsp.exec_cmd("${shellIpc.lock}"))
    hl.bind(mainMod .. " + TAB",   hl.dsp.exec_cmd("${shellIpc.overview}"))
    hl.bind(mainMod .. " + V",     hl.dsp.exec_cmd("${shellIpc.clipboard}"))
    hl.bind(mainMod .. " + N",     hl.dsp.exec_cmd("${shellIpc.notifs}"))
    hl.bind(mainMod .. " + M",     hl.dsp.exec_cmd("${cfg.terminal} -e btop"))
    hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("${shellIpc.settings}"))

    -- Scratchpad ("magic" special workspace)
    hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

    ${lidSwitchLua}

    -- App float rules (float targets that are actually installed). The two
    -- generic rules (suppress-maximize-events, fix-xwayland-drags) are
    -- deliberately NOT set here: lucid's windowrules module below defines
    -- them identically.
    hl.window_rule({ name = "float-file-roller", match = { class = "org.gnome.FileRoller" }, float = true })
    hl.window_rule({ name = "float-loupe",       match = { class = "org.gnome.Loupe" }, float = true })
    -- Firefox Bitwarden popup (German-locale title)
    hl.window_rule({ name = "float-bitwarden-popup", match = { class = "firefox", title = "Erweiterung: .*Bitwarden.*" }, float = true })

    -- Lucid runtime modules (deployed from the lucid flake input by
    -- home/lucid.nix; on the DMS path none of these exist and every pcall
    -- falls back silently — the binds above are then the only bind source).
    -- binds.lua loads ~/.config/lucid/keybinds.json — the complete bind set
    -- (launcher, workspaces, scratchpads, mouse, media and screenshot
    -- keys); windowrules floats lucid surfaces; layerrules blurs its glass
    -- layers (DMS manages its own layer namespaces); glass is the per-app
    -- translucency loader (Settings > Glass writes
    -- ~/.config/hypr/lucid-glass.lua). pcall keeps the compositor alive if
    -- a module is mid-sync or missing.
    pcall(require, "modules.json")
    pcall(require, "modules.specials")
    pcall(require, "modules.binds")
    pcall(require, "modules.windowrules")
    pcall(require, "modules.layerrules")
    pcall(require, "modules.glass")

    -- Autostart. The session shell itself starts via its own user unit
    -- (lucid.service / the DMS module's dms service), wanted by
    -- graphical-session.target — upstream's modules.autostart.lua is
    -- deliberately NOT required here (it would start a second shell next
    -- to the service). Same for lucid's modules.plugins.lua (deployed, but
    -- requiring it compiles the hypr-dynamic-cursors plugin at login).
    -- Cursor theme/size arrive via the systemd user
    -- manager (home/theme.nix) through uwsm — no env vars needed. The
    -- session shell runs its own polkit agent (lucidpolkit / DMS's
    -- built-in), so hyprpolkitagent is not autostarted (kept installed as
    -- a manual fallback).
    hl.on("hyprland.start", function()
        -- Clipboard history backend (lucid's clipboard launcher reads
        -- cliphist; on DMS it stays as harmless re-paste history).
        hl.exec_cmd("wl-paste --watch cliphist store")
    end)

    ${cfg.extraConfig}
  '';
in
{
  options.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland session config (Lua). Pair with features.desktop-hyprland on the NixOS side";

    terminal = lib.mkOption {
      type = lib.types.str;
      # kitty (single-instance wrap, home/terminal.nix) — also lucid's F9
      # terminal bind.
      default = "kitty";
      description = "Terminal command for the SUPER+T bind";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "nautilus";
      description = "File manager for the SUPER+SHIFT+E bind";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "firefox";
      description = "Browser for the SUPER+F1 bind";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            output = lib.mkOption {
              type = lib.types.str;
              description = "Connector name (e.g. eDP-1); empty string = fallback rule for all monitors";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "preferred";
              description = "Mode, e.g. preferred / 3072x1920@120 / disabled";
            };
            position = lib.mkOption {
              type = lib.types.str;
              default = "auto";
              description = "Position, e.g. auto / 0x0";
            };
            scale = lib.mkOption {
              type = lib.types.str;
              default = "auto";
              description = "Scale, e.g. auto / 2";
            };
          };
        }
      );
      default = [ ];
      description = "Monitors; empty list = Hyprland defaults (preferred mode, auto placement)";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra Lua appended verbatim to hyprland.lua";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "hypr/hyprland.lua".text = hyprlandLua;
    };
  };
}
