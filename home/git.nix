{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.git;
in
{
  # Namespace changed from features.git to programs.git
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

    # This extends the standard programs.git.delta options if they exist,
    # or defines them if they don't.
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
    programs.delta = {
      inherit (cfg.delta) enable;
      options = {
        navigate = true;
        line-numbers = true;
        hyperlinks = true;
        side-by-side = cfg.delta.sideBySide;
      };
    };

    programs.git = {
      enable = true;
      package = pkgs.gitMinimal;
      
      # Use the extended options defined above
      userName = cfg.identity.name;
      userEmail = cfg.identity.email;

      extraConfig = {
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
