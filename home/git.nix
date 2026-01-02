{ config, lib, pkgs, ... }:

let
  cfg = config.programs.git;
in
{
  options.programs.git = {
    identity = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Daher12";
        description = "Git user name";
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "133640261+Daher12@users.noreply.github.com";
        description = "Git user email";
      };
    };

    delta = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable delta diff viewer";
      };

      sideBySide = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use side-by-side diff view";
      };
    };

    defaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Default branch name for new repositories";
    };

    editor = lib.mkOption {
      type = lib.types.str;
      default = "ox";
      description = "Text editor for git operations";
    };
  };

  config = lib.mkMerge [
    {
      home.packages = lib.mkIf cfg.delta.enable [ pkgs.delta ];

      programs.git = {
        enable = true;
        package = pkgs.gitMinimal;

        settings = {
          user = {
            name = cfg.identity.name;
            email = cfg.identity.email;
          };

          init.defaultBranch = cfg.defaultBranch;
          core.editor = cfg.editor;

          pull.rebase = true;
          rebase.autoStash = true;
          fetch.prune = true;
          push.autoSetupRemote = true;

          "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";

          diff = {
            colorMoved = "default";
            algorithm = "histogram";
          };

          merge.conflictStyle = "zdiff3";
        };
      };
    }

    (lib.mkIf cfg.delta.enable {
      programs.git.settings = {
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";

        delta = {
          navigate = true;
          line-numbers = true;
          hyperlinks = true;
          side-by-side = cfg.delta.sideBySide;
        };
      };
    })
  ];
}
