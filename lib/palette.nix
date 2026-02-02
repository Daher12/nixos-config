# lib/palette.nix
{
  activeName ? "nord",
}:

let
  # Registry of available palettes (lazy)
  available = {
    nord = import ./palettes/nord.nix;
    rosePine = import ./palettes/rose-pine.nix;
  };

  active =
    if builtins.hasAttr activeName available then
      available.${activeName}
    else
      throw "palette: Unknown theme '${activeName}'. Available: ${builtins.concatStringsSep ", " (builtins.attrNames available)}";
in
active // { palettes = available; }
