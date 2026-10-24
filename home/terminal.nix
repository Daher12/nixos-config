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

    (lib.mkIf cfg.kitty.enable {
      # The default terminal: SUPER+T
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
        # Colors: static Nord from kitty-themes — the same palette ghostty's
        # theme = "Nord" loads. Kitty deliberately does NOT follow lucid's
        # light/dark mode (2026-09-30: a bright terminal feels wrong): the
        # desktop flips at 08:00/19:00 via lucid-auto-mode, the terminal
        # stays dark. lucid's apply-theme.sh / matugen keep rewriting
        # ~/.config/kitty/matugen-colors.conf, but nothing includes it.
        # HM writes the themeFile include BEFORE `settings` (order 520 vs
        # 540), so colors are left to the theme here.
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
          # Lucid's Glass slider owns terminal opacity on Hyprland hosts (see
          # extraConfig below) — there the static value would fight the
          # slider. Kept for the GNOME generations (latitude, yoga-gnome),
          # where lucid never runs and lucid-glass.conf does not exist.
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
        # nord ships with btop (share/btop/themes) — matches the terminal,
        # bat and Hyprland-border palette.
        settings.color_theme = "nord";
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
