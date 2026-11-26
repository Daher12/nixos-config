{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.fonts;
in
{
  options.features.fonts = {
    enable = lib.mkEnableOption "font packages and configuration";
  };

  config = lib.mkIf cfg.enable {
    fonts = {
      # LOAD-BEARING plain false: graphical-desktop.nix (pulled in by every
      # desktop session — GNOME and niri alike) sets mkDefault true, which
      # would drag in the dejavu/freefont/gyre/liberation/unifont/noto-cjk
      # baseline next to the curated list below. (audit 2026-11-26: the
      # snapshot proof caught this — the option default is false, but the
      # merged desktop value is not.)
      enableDefaultPackages = false;
      fontDir.enable = true;

      packages = [
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-color-emoji
        pkgs.nerd-fonts.caskaydia-cove
        pkgs.inter
        pkgs.cantarell-fonts
      ];

      fontconfig = {
        defaultFonts = {
          serif = [ "Noto Serif" ];
          sansSerif = [
            "Inter"
            "Noto Sans"
          ];
          monospace = [ "CaskaydiaCove Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
        # hinting/antialias not set: enable=true, style="slight" are the
        # upstream defaults.
        subpixel.rgba = "rgb";
      };
    };
  };
}
