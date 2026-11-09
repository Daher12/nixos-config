{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.terminal;

  # Nord subset — only the 5 values actually consumed by ghostty + fzf.
  # No palette module, no hexToRgb, no validation machinery.
  nord = {
    nord0 = "#2E3440";
    nord1 = "#3B4252";
    nord3 = "#4C566A";
    nord4 = "#D8DEE9";
    nord9 = "#81A1C1";
  };

  # The niri/Noctalia host (yoga-niri) runs Rosé Pine end to end — the
  # shell and GTK are Rosé Pine via home/noctalia.nix — so the terminal
  # (foot there, kitty on the lucid/GNOME hosts), fzf and btop follow it
  # there (main/dark variant only: the terminal never follows light/dark).
  # Every other host stays Nord; the Nord values below are the ones they
  # always had.
  rosePineTerminal = config.desktop.noctalia.enable;

  # fzf option-string roles, per palette. hl+/marker get rose/gold on
  # Rosé Pine for a touch of color; Nord keeps its single-accent mapping.
  fzfColors =
    if rosePineTerminal then
      {
        bg = "#191724"; # base
        bgPlus = "#403d52"; # highlight med
        spinner = "#c4a7e7"; # iris
        hl = "#6e6a86"; # muted
        fg = "#e0def4"; # text
        header = "#6e6a86"; # muted
        info = "#c4a7e7"; # iris
        pointer = "#c4a7e7"; # iris
        marker = "#f6c177"; # gold
        fgPlus = "#e0def4"; # text
        prompt = "#c4a7e7"; # iris
        hlPlus = "#ebbcba"; # rose
      }
    else
      {
        bg = nord.nord0;
        bgPlus = nord.nord1;
        spinner = nord.nord9;
        hl = nord.nord3;
        fg = nord.nord4;
        header = nord.nord3;
        info = nord.nord9;
        pointer = nord.nord9;
        marker = nord.nord9;
        fgPlus = nord.nord4;
        prompt = nord.nord9;
        hlPlus = nord.nord9;
      };

  # Rosé Pine (main) btop theme, verbatim from upstream
  # github.com/rose-pine/btop (rose-pine.theme, MIT). Vendored because btop
  # 1.4.8 ships no rose-pine theme (nord is the only one of the pair in
  # share/btop/themes); btop's color_theme accepts a full path.
  rosePineBtopTheme = pkgs.writeText "rose-pine.theme" ''
    # Main background, empty for terminal default, need to be empty if you want transparent background
    theme[main_bg]="#191724"
    # Base

    # Main text color
    theme[main_fg]="#e0def4"
    # Text

    # Title color for boxes
    theme[title]="#908caa"
    # Subtle

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="#e0def4"
    # Text

    # Background color of selected item in processes box
    theme[selected_bg]="#524f67"
    # HL High

    # Foreground color of selected item in processes box
    theme[selected_fg]="#f6c177"
    # Gold

    # Color of inactive/disabled text
    theme[inactive_fg]="#403d52"
    # HL Med

    # Color of text appearing on top of graphs, i.e uptime and current network graph scaling
    theme[graph_text]="#9ccfd8"
    # Foam

    # Background color of the percentage meters
    theme[meter_bg]="#9ccfd8"
    # Foam

    # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
    theme[proc_misc]="#c4a7e7"
    # Iris

    # Cpu box outline color
    theme[cpu_box]="#ebbcba"
    # Rose

    # Memory/disks box outline color
    theme[mem_box]="#31748f"
    # Pine

    # Net up/down box outline color
    theme[net_box]="#c4a7e7"
    # Iris

    # Processes box outline color
    theme[proc_box]="#eb6f92"
    # Love

    # Box divider line and small boxes line color
    theme[div_line]="#6e6a86"
    # Muted

    # Temperature graph colors
    theme[temp_start]="#ebbcba"
    # Rose
    theme[temp_mid]="#f6c177"
    # Gold
    theme[temp_end]="#eb6f92"
    # Love

    # CPU graph colors
    theme[cpu_start]="#f6c177"
    # Gold
    theme[cpu_mid]="#ebbcba"
    # Rose
    theme[cpu_end]="#eb6f92"
    # Love

    # Mem/Disk free meter
    # all love
    theme[free_start]="#eb6f92"
    theme[free_mid]="#eb6f92"
    theme[free_end]="#eb6f92"

    # Mem/Disk cached meter
    # all iris
    theme[cached_start]="#c4a7e7"
    theme[cached_mid]="#c4a7e7"
    theme[cached_end]="#c4a7e7"

    # Mem/Disk available meter
    # all pine
    theme[available_start]="#31748f"
    theme[available_mid]="#31748f"
    theme[available_end]="#31748f"

    # Mem/Disk used meter
    # all rose
    theme[used_start]="#ebbcba"
    theme[used_mid]="#ebbcba"
    theme[used_end]="#ebbcba"

    # Download graph colors
    # Pine for start, foam for the rest
    theme[download_start]="#31748f"
    theme[download_mid]="#9ccfd8"
    theme[download_end]="#9ccfd8"

    # Upload graph colors
    theme[upload_start]="#ebbcba"
    # Rose for start
    theme[upload_mid]="#eb6f92"
    # Love for mid and end
    theme[upload_end]="#eb6f92"

    # Process box color gradient for threads, mem and cpu usage
    theme[process_start]="#31748f"
    # Pine
    theme[process_mid]="#9ccfd8"
    # Foam for mid and end
    theme[process_end]="#9ccfd8"
  '';
in
{
  options.programs.terminal = {
    ghostty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # 2026-09-27: kitty won the default slot (SUPER+T and lucid's F9).
        # Flip to true per host to bring ghostty back.
        default = false;
        description = "Enable Ghostty terminal";
      };

      fontSize = lib.mkOption {
        type = lib.types.int;
        default = 11;
        description = "Font size";
      };

      fontFamily = lib.mkOption {
        type = lib.types.str;
        default = "CaskaydiaCove Nerd Font";
        description = "Font family";
      };
    };

    kitty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Kitty terminal (single-instance wrapped)";
      };

      fontSize = lib.mkOption {
        type = lib.types.int;
        default = 11;
        description = "Font size";
      };

      fontFamily = lib.mkOption {
        type = lib.types.str;
        default = "CaskaydiaCove Nerd Font";
        description = "Font family";
      };
    };

    fish = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Fish shell";
      };
    };

    utilities = {
      btop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable btop system monitor";
      };

      fastfetch = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable fastfetch system info";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ghostty.enable {
      programs.ghostty = {
        enable = true;
        package = pkgs.ghostty;

        # Static Nord everywhere — no matugen branch: the shell's dynamic
        # theming (Lucid) doesn't touch terminals. The 0.93 translucency only
        # makes sense under the Wayland compositor.
        settings = {
          font-family = cfg.ghostty.fontFamily;
          font-size = cfg.ghostty.fontSize;
          window-decoration = "auto";
          command = "fish --login --interactive";
          theme = "Nord";
          background = nord.nord0;
          foreground = nord.nord4;
        }
        // (lib.optionalAttrs config.desktop.hyprland.enable {
          background-opacity = 0.93;
        });
      };
    })

    (lib.mkIf (cfg.kitty.enable && !config.desktop.niri.enable) {
      # The default terminal of the lucid/Hyprland and GNOME hosts: SUPER+T
      # (desktop.hyprland.terminal) and lucid's F9 bind both open kitty, and
      # lucid's Glass slider owns its opacity — kitty stays THEIR terminal.
      # On the niri host foot replaced it entirely (2026-11-08, foot trial
      # won); this gate keeps kitty out of that attr.
      # Single-instance wrap:
      # --single-instance is CLI-only (no kitty.conf equivalent), and it is the
      # startup-time tweak — the first launch pays the full cost (GL init,
      # embedded Python), every later `kitty` just IPCs the running instance and
      # opens a new window near-instantly. Caveats: a running instance keeps its
      # loaded config until reload (ctrl+shift+f5) or restart, so rebuilds don't
      # hot-apply; all windows share one process, so a crash takes them all.
      programs.kitty = {
        enable = true;
        package = pkgs.symlinkJoin {
          name = "kitty-single-instance";
          paths = [ pkgs.kitty ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/kitty --add-flags "--single-instance"
          '';
        };
        # Colors: static Nord from kitty-themes. Kitty deliberately does
        # NOT follow light/dark mode (2026-09-30: a bright terminal feels
        # wrong): the shell flips via the sun schedule, the terminal stays
        # dark. lucid's apply-theme.sh / matugen keep rewriting
        # ~/.config/kitty/matugen-colors.conf, but nothing includes it.
        # HM writes the themeFile include BEFORE `settings` (order 520 vs
        # 540), so `settings` colors would win over a theme regardless.
        # (This block only evaluates on the lucid/GNOME hosts — the niri
        # host runs foot — so the former Rosé Pine branches for the
        # noctalia attr were dead and were removed 2026-11-08.)
        themeFile = "Nord";
        settings = {
          font_family = cfg.kitty.fontFamily;
          font_size = cfg.kitty.fontSize;
          hide_window_decorations = "yes";
          shell = "fish --login --interactive";
          scrollback_lines = 10000;
          update_check_interval = 0;
          # pts, not px: 12pt ≈ 16px at this DPI, matching Hyprland's
          # decoration rounding = 16 (home/hyprland.nix). Without padding the
          # prompt glyphs sit under the rounded corners and get clipped.
          window_padding_width = 12;
        }
        // (lib.optionalAttrs (!config.desktop.lucid.enable) {
          # Lucid's Glass slider owns terminal opacity on Hyprland hosts
          # (see extraConfig below) — there the static value would fight
          # the slider. These are the GNOME generations (latitude,
          # yoga-gnome): 0.93, mutter has no blur. (The former "niri host
          # draws fully opaque" branch was dead — kitty never evaluates on
          # the niri attr.)
          background_opacity = "0.93";
        });
        # Lucid Glass (Settings > General > Glass) writes
        # ~/.config/kitty/lucid-glass.conf and signals kitty (USR1) to reload.
        # The include must live here because HM owns kitty.conf as a read-only
        # store symlink — lucid's own auto-append into kitty.conf fails
        # silently (EACCES) and its .pre-lucid-glass backup marks the attempt
        # as done, so it never retries. Absolute path because kitty.conf
        # itself is a store symlink; included directives land last, so the
        # Glass slider wins over `settings` (and 1.00 = fully opaque at Off).
        extraConfig = lib.mkIf config.desktop.lucid.enable ''
          include ${config.home.homeDirectory}/.config/kitty/lucid-glass.conf
        '';
      };
    })

    # FOOT — THE terminal of the niri host (foot trial won over kitty
    # 2026-11-08; kitty is absent from this attr, see the kitty gate above).
    # Why foot: lightest Wayland terminal class (~15-40MB vs kitty's
    # ~150-300MB), `--server` daemon = instant window open (Mod+T spawns
    # footclient, home/niri.nix), best-in-class fractional-scale and damage
    # handling at 120Hz. Trade-offs: no ligatures, plain foot.ini.
    # Theming: Rosé Pine main palette (verbatim upstream hexes, same as the
    # kitty block above uses on the lucid/GNOME hosts), same font; foot
    # draws FULLY OPAQUE and sits under the compositor rule in
    # home/niri.nix (opacity 0.75 + xray blur) — user picked full frost
    # after trialing plain client-side translucency. Known trade-off:
    # niri's focus-keyed frost sampling (pixel-proven 2026-11-07) applies
    # to foot identically — visible only when comparing two windows in
    # different focus states.
    #
    # foot 1.27 key facts (validated against `foot --check-config` of the
    # live binary — never write foot config from memory):
    # - cursor COLORS = `cursor` in [colors-dark], TWO RRGGBB values
    #   `<text> <block>` (the man page's example mislabels the order; its
    #   formal definition is authoritative). No `cursor-text` key; the
    #   [cursor] section only styles shape/blink/thickness.
    # - transparency = [colors-dark] `alpha` (0-1 float; `alpha-mode
    #   default` = only default-bg cells translucent, kitty's per-cell
    #   model). Colors are strict RRGGBB — hex-alpha suffixes REJECTED.
    # - palette section is [colors-dark] ([colors] deprecated, warns per
    #   key).
    # - `dpi-aware=no` = font size in LOGICAL px (kitty parity); foot's
    #   default `auto` sizes pt against physical DPI — 2x too tall at this
    #   panel's scale 2.
    (lib.mkIf config.desktop.niri.enable {
      programs.foot = {
        enable = true;

        # One daemon, instant client windows (`footclient`, wired as the
        # Mod+Shift+T spawn target).
        server.enable = true;

        settings = {
          main = {
            font = "CaskaydiaCove Nerd Font Mono:size=11";
            shell = "fish --login --interactive";
            # Kitty parity: font size in LOGICAL pixels. foot's default
            # `dpi-aware=auto` resolves pt against physical DPI — at this
            # panel's scale 2 that renders the font ~2x too tall.
            dpi-aware = "no";
            # pts-vs-px note from kitty applies: generous pad so prompt
            # glyphs clear the rounded corners.
            pad = "12x12";
          };

          scrollback.lines = 10000;

          # Rosé Pine main — github.com/rose-pine (same palette as the
          # kitty block above). Foot draws FULLY OPAQUE: the frost +
          # transparency are compositor-owned, identical to kitty (the
          # kitty/foot window rule in home/niri.nix sets `opacity 0.75` +
          # xray blur) — one render stack for both terminals. User picked
          # full frost over plain translucency 2026-11-07; the known
          # trade-off (niri's focus-keyed frost sampling, pixel-proven
          # rounds 5-8) applies to foot the same as kitty.
          colors-dark = {
            foreground = "e0def4";
            background = "191724";
            selection-foreground = "e0def4";
            selection-background = "403d52";
            urls = "c4a7e7";
            # Man-page order: <text-foreground> <cursor-block> (formal
            # definition; the page's own example mislabels it). Kitty
            # parity: dark 524f67 block, light e0def4 text.
            cursor = "e0def4 524f67";
            regular0 = "26233a";
            regular1 = "eb6f92";
            regular2 = "31748f";
            regular3 = "f6c177";
            regular4 = "9ccfd8";
            regular5 = "c4a7e7";
            regular6 = "ebbcba";
            regular7 = "e0def4";
            bright0 = "6e6a86";
            bright1 = "eb6f92";
            bright2 = "31748f";
            bright3 = "f6c177";
            bright4 = "9ccfd8";
            bright5 = "c4a7e7";
            bright6 = "ebbcba";
            bright7 = "e0def4";
          };
        };
      };
    })

    (lib.mkIf cfg.fish.enable {
      programs.fish = {
        enable = true;

        # update-safe wrapper: `nus <host> [test|boot|switch|build-only]
        # [--pin <input>]`. Lives in the shared home so BOTH laptops have it
        # (was yoga-only until 2026-10-19); nix-media (headless, git-only HM)
        # calls the script by path.
        functions.nus = ''
          "$HOME/nixos-config/scripts/update-safe" $argv
        '';

        interactiveShellInit = ''
          set -g fish_greeting

          set -x FZF_DEFAULT_OPTS (printf "\
            --color=bg+:%s,bg:%s,spinner:%s,hl:%s \
            --color=fg:%s,header:%s,info:%s,pointer:%s \
            --color=marker:%s,fg+:%s,prompt:%s,hl+:%s" \
            "${fzfColors.bgPlus}" "${fzfColors.bg}" "${fzfColors.spinner}" "${fzfColors.hl}" \
            "${fzfColors.fg}" "${fzfColors.header}" "${fzfColors.info}" "${fzfColors.pointer}" \
            "${fzfColors.marker}" "${fzfColors.fgPlus}" "${fzfColors.prompt}" "${fzfColors.hlPlus}")
        '';

        plugins = [
          {
            name = "hydro";
            inherit (pkgs.fishPlugins.hydro) src;
          }
          {
            name = "fzf-fish";
            inherit (pkgs.fishPlugins.fzf-fish) src;
          }
          {
            name = "done";
            inherit (pkgs.fishPlugins.done) src;
          }
        ];
      };
    })

    (lib.mkIf cfg.utilities.btop {
      programs.btop = {
        enable = true;
        # nord ships with btop (share/btop/themes) — matches the terminal,
        # bat and Hyprland-border palette. On the niri host color_theme
        # takes the vendored Rosé Pine path instead (btop 1.4.8 ships no
        # rose-pine theme; see rosePineBtopTheme above). Noctalia's own
        # btop template output (noctalia.theme) stays unused — btop.conf
        # is a read-only HM symlink it cannot rewrite.
        settings.color_theme = if rosePineTerminal then toString rosePineBtopTheme else "nord";
      };
    })

    (lib.mkIf cfg.utilities.fastfetch {
      programs.fastfetch = {
        enable = true;
        package = pkgs.fastfetch.minimal;
      };
    })

    {
      programs.eza = {
        enable = true;
        git = true;
      };

      programs.bat = {
        enable = true;
        # Nord everywhere — bat 0.26.1 ships no Rose Pine theme, so the
        # Rosé Pine sync stops at the terminal/fzf/btop layer on the niri
        # host. Revisit on a bat bump that adds it.
        config.theme = "Nord";
      };
    }

    {
      home.packages = [
        pkgs.fzf
        pkgs.dust
        pkgs.duf
        pkgs.procs
        pkgs.rsync
        pkgs.ripgrep
        pkgs.fd
        pkgs.sd
        pkgs.jq
        pkgs.ox
        pkgs.grc
        pkgs.nh
        pkgs.nvd
        pkgs.nix-output-monitor
        pkgs.p7zip
        pkgs.unzip
      ];
    }
  ];
}
