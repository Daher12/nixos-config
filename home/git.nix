{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.git;
in
{
  options.features.git = {
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

  config = {
    # 1. Standalone Delta Module (New Standard)
    programs.delta = {
      inherit (cfg.delta) enable;
      enableGitIntegration = true; # Explicitly required now
      options = {
        navigate = true;
        line-numbers = true;
        hyperlinks = true;
        side-by-side = cfg.delta.sideBySide;
      };
    };

    # 2. Main Git Module
    programs.git = {
      enable = true;
      package = pkgs.gitMinimal;

      # Consolidated structured settings
      settings = {
        # Identity
        user.name = cfg.identity.name;
        user.email = cfg.identity.email;

        # Config
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
  };
}
