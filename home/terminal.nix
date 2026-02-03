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
        default = true;
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

    fish = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Fish shell";
      };

      plugins = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Plugin name";
              };
              src = lib.mkOption {
                type = lib.types.package;
                description = "Plugin source";
              };
            };
          }
        );
        default = [ ];
        description = "Fish plugins to install";
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
        package = pkgs.unstable.ghostty;

        settings = {
          theme = "Nord";
          background = nord.nord0;
          foreground = nord.nord4;
          font-family = cfg.ghostty.fontFamily;
          font-size = cfg.ghostty.fontSize;
          window-decoration = "auto";
          command = "fish --login --interactive";
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
        ]
        ++ cfg.fish.plugins;
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
        package = pkgs.fastfetchMinimal;
      };
    })

    {
      home.packages = with pkgs; [
        rsync
        ripgrep
        fd
        sd
        jq
        ox
        grc
        eza
        nh
        nvd
        nix-output-monitor
        p7zip
        unzip
      ];
    }
  ];
}
