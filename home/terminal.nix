{
  config,
  lib,
  pkgs,
  palette,
  ...
}:

let
  cfg = config.programs.terminal;
  p = palette.colors;
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
          background = p.nord0;
          foreground = p.nord4;
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
            "${p.nord1}" "${p.nord0}" "${p.nord9}" "${p.nord3}" \
            "${p.nord4}" "${p.nord3}" "${p.nord9}" "${p.nord9}" \
            "${p.nord9}" "${p.nord4}" "${p.nord9}" "${p.nord9}")
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
