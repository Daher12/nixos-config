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

      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        nerd-fonts.symbols-only
        nerd-fonts.caskaydia-cove
        fira-code
        inter
        roboto
        cantarell-fonts
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
