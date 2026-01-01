{ pkgs, ... }:

{
  # Delta is configured via git config (most stable across Home Manager versions).
  home.packages = [ pkgs.delta ];

  programs.git = {
    enable = true;

    # Keep minimal closure;
    # switch to pkgs.git if you need extra tooling (send-email, svn, etc.).
    package = pkgs.gitMinimal;

    # [FIX] All git config now lives under 'settings' to silence warnings
    settings = {
      # User Identity
      user = {
        name  = "Daher12";
        email = "133640261+Daher12@users.noreply.github.com";
      };

      # Init & Remote Behaviors
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;
      push.autoSetupRemote = true;

      # Editor
      core.editor = "ox";

      # Force SSH for GitHub
      # Note: Quoted attribute path for complex keys
      "url \"ssh://git@github.com/\"".insteadOf = "https://github.com/";

      # Delta (Diff Viewer) Integration
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      
      delta = {
        navigate = true;
        line-numbers = true;
        hyperlinks = true;
        side-by-side = false;
      };

      diff = {
        colorMoved = "default";
        algorithm = "histogram";
      };

      merge.conflictStyle = "zdiff3";
    };
  };
}
