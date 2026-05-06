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
      enableDefaultPackages = false;
      fontDir.enable = true;

      packages = [
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-color-emoji
        pkgs.nerd-fonts.caskaydia-cove
        pkgs.fira-code
        pkgs.inter
        pkgs.roboto
        pkgs.cantarell-fonts
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = [ "Noto Serif" ];
          sansSerif = [
            "Inter"
            "Noto Sans"
          ];
          monospace = [ "CaskaydiaCove Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
        antialias = true;
        hinting = {
          enable = true;
          style = "slight";
        };
        subpixel.rgba = "rgb";
      };
    };
  };
}
