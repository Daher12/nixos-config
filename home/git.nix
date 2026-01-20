{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitMinimal;

    settings = {
      user = {
        name = "Daher12";
        email = "133640261+Daher12@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      core.editor = "ox";

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

  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      hyperlinks = true;
    };
  };
}
