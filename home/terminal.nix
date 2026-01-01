{ pkgs, unstable, palette, ... }:

let
  p = palette.colors;
in
{
  # --- GHOSTTY ---
  programs.ghostty = {
    enable   = true;
    package  = unstable.ghostty;
    settings = {
      theme             = "Nord";
      # Explicit fallback colors from our palette source of truth
      background        = p.nord0;
      foreground        = p.nord4;

      font-family       = "CaskaydiaCove Nerd Font";
      font-size         = 11;

      # Ghostty expects a string value (e.g. "auto" or "none"), not a boolean.
      window-decoration = "auto";

      command           = "fish --login --interactive";
    };
  };

  # --- FISH SHELL ---
  programs.fish = {
    enable = true;
    # Inject dynamic palette colors into FZF env vars
    interactiveShellInit = ''
      set -g fish_greeting

      # FZF Nord Theme
      set -x FZF_DEFAULT_OPTS "\
        --color=bg+:${p.nord1},bg:${p.nord0},spinner:${p.nord9},hl:${p.nord3} \
        --color=fg:${p.nord4},header:${p.nord3},info:${p.nord9},pointer:${p.nord9} \
        --color=marker:${p.nord9},fg+:${p.nord4},prompt:${p.nord9},hl+:${p.nord9}"
    '';

    plugins = [
      { name = "hydro";    src = pkgs.fishPlugins.hydro.src; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "done";     src = pkgs.fishPlugins.done.src; }
    ];
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "tomorrow-night";
    };
  };

  programs.fastfetch = {
    enable = true;
    package = pkgs.fastfetchMinimal;
  };

  home.packages = with pkgs; [
    rsync ripgrep fd sd jq ox grc eza
    nh nvd nix-output-monitor # Nix Helper Tools
    p7zip
    unzip
  ];
}

