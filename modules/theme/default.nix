{ config, lib, ... }:

let
  # Read palette registry once (values stay lazy)
  paletteRegistry = (import ../../lib/palette.nix { activeName = "nord"; }).palettes;
  paletteNames = builtins.attrNames paletteRegistry;

  cfg = config.theme;
in
{
  options.theme = {
    paletteName = lib.mkOption {
      type = lib.types.enum paletteNames;
      default = "nord";
      description = "Active theme palette name for the system.";
    };

    palette = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Resolved palette attrset derived from theme.paletteName.";
    };
  };

  config = {
    theme.palette = import ../../lib/palette.nix { activeName = cfg.paletteName; };

    # Backward-compatible module arg for existing modules that take `palette` as a parameter.
    _module.args.palette = config.theme.palette;

    # Make palette available to Home Manager modules too.
    home-manager.extraSpecialArgs.palette = config.theme.palette;
  };
}
