{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.kmscon;

  palette = config.theme.palette;
  p = palette.colors;

  paletteUtils = import ../../lib/palettes/utils.nix;
  toRgb = paletteUtils.hexToRgb;
in
{
  options.features.kmscon = {
    enable = lib.mkEnableOption "KMSCon graphical console";
  };

  config = lib.mkIf cfg.enable {
    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;

    services.kmscon = {
      enable = true;
      hwRender = true;

      fonts = [
        {
          name = "CaskaydiaCove Nerd Font";
          package = pkgs.nerd-fonts.caskaydia-cove;
        }
      ];

      extraConfig = ''
        font-size=14
        font-dpi=120
        sb-size=10000

        palette=custom
        palette-background=${toRgb p.nord0}
        palette-foreground=${toRgb p.nord4}

        palette-black=${toRgb p.nord1}
        palette-red=${toRgb p.nord11}
        palette-green=${toRgb p.nord14}
        palette-yellow=${toRgb p.nord13}
        palette-blue=${toRgb p.nord9}
        palette-magenta=${toRgb p.nord15}
        palette-cyan=${toRgb p.nord8}
        palette-light-grey=${toRgb p.nord5}

        palette-dark-grey=${toRgb p.nord3}
        palette-light-red=${toRgb p.nord11}
        palette-light-green=${toRgb p.nord14}
        palette-light-yellow=${toRgb p.nord13}
        palette-light-blue=${toRgb p.nord9}
        palette-light-magenta=${toRgb p.nord15}
        palette-light-cyan=${toRgb p.nord7}
        palette-white=${toRgb p.nord6}
      '';
    };
  };
}
