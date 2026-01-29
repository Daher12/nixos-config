let
  # Registry of available palettes
  # Diese Imports sind lazy. mkPalette wird hier noch NICHT ausgeführt.
  available = {
    nord = import ./palettes/nord.nix;
    rosePine = import ./palettes/rose-pine.nix;
  };

  # CONFIGURATION: Select theme by canonical name
  activeName = "nord";
  # activeName = "rosePine";

  # Guard: Fail with a helpful list if the name is wrong
  active =
    if builtins.hasAttr activeName available then
      available.${activeName}
    else
      throw "palette: Unknown theme '${activeName}'. Available: ${builtins.concatStringsSep ", " (builtins.attrNames available)}";
in
# Export active theme + registry
# deepSeq läuft erst, wenn 'active' Attribute (z.B. colors) abgerufen werden.
active
// {
  palettes = available;
}
