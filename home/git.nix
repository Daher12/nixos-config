{
  config,
  pkgs,
  ...
}:

{
  # Directly configure the upstream module.
  # No custom options needed.
  programs.git = {
    enable = true;
    package = pkgs.gitMinimal;

    # Set defaults here. If you need to override them per-host,
    # you can just set 'programs.git.userName = "..."' in that host's home.nix.
    userName = "Daher12";
    userEmail = "133640261+Daher12@users.noreply.github.com";

    extraConfig = {
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

  # Configure Delta directly using its own module
  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      hyperlinks = true;
      # side-by-side = false; # Uncomment/Change here if needed
    };
  };
}
