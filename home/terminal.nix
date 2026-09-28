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
in
{
  options.programs.terminal = {
    ghostty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # 2026-09-27: kitty won the default slot (SUPER+T, matugen-themed).
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

        # Static Nord everywhere (2026-09-27: kitty is the default terminal,
        # so the DMS-era dankcolors matugen branch is gone with DMS). The
        # 0.93 translucency only makes sense under the Wayland compositor.
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

    (lib.mkIf cfg.kitty.enable {
      # The default terminal (2026-09-27 consolidation): SUPER+T
      # (desktop.hyprland.terminal) and lucid's F9 bind both open kitty.
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
        # Colors, two regimes: on the lucid attr matugen owns the palette —
        # its config.toml (home/lucid.nix) renders
        # ~/.config/kitty/matugen-colors.conf from the wallpaper (lucidSync
        # seeds that file with Nord until then), included via extraConfig.
        # Everywhere else: static Nord from kitty-themes, the same palette
        # ghostty's theme = "Nord" loads. HM writes a themeFile include
        # BEFORE `settings` (order 520 vs 540), so colors are deliberately
        # left to the theme/include here either way.
        themeFile = lib.mkIf (!config.desktop.lucid.enable) "Nord";
        extraConfig = lib.mkIf config.desktop.lucid.enable ''
          include matugen-colors.conf
        '';
        settings = {
          font_family = cfg.kitty.fontFamily;
          font_size = cfg.kitty.fontSize;
          background_opacity = "0.93";
          hide_window_decorations = "yes";
          shell = "fish --login --interactive";
          scrollback_lines = 10000;
          update_check_interval = 0;
        };
      };
    })

    (lib.mkIf cfg.fish.enable {
      programs.fish = {
        enable = true;

        interactiveShellInit = ''
          set -g fish_greeting

          set -x FZF_DEFAULT_OPTS (printf "\
            --color=bg+:%s,bg:%s,spinner:%s,hl:%s \
            --color=fg:%s,header:%s,info:%s,pointer:%s \
            --color=marker:%s,fg+:%s,prompt:%s,hl+:%s" \
            "${nord.nord1}" "${nord.nord0}" "${nord.nord9}" "${nord.nord3}" \
            "${nord.nord4}" "${nord.nord3}" "${nord.nord9}" "${nord.nord9}" \
            "${nord.nord9}" "${nord.nord4}" "${nord.nord9}" "${nord.nord9}")
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
        settings.color_theme = "tomorrow-night";
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
