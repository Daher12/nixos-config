{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitMinimal;

    settings = {
      user = {
        name = "Daher12";
        email = "133640261+Daher12@users.noreply.github.com";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvXYwk5iekNITQ2UrkllAeaA/Ax7NusdRqmYFeGsR9p";
      };
      init.defaultBranch = "main";
      core.editor = "ox";

      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;
      push.autoSetupRemote = true;

      "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";

      gpg.format = "ssh";
      commit.gpgsign = true;

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
