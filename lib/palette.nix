let
  # Registry of available palettes
  available = {
    nord = import ./palettes/nord.nix;
    rosePine = import ./palettes/rose-pine.nix;
  };

  # CONFIGURATION: Select theme by canonical name
  activeName = "nord"; 
  # activeName = "rosePine";

  # Guard: Fail with a helpful list if the name is wrong
  active = 
    if builtins.hasAttr activeName available
    then available.${activeName}
    else throw "palette: Unknown theme '${activeName}'. Available: ${builtins.concatStringsSep ", " (builtins.attrNames available)}";
in
# Export active theme + registry
active // {
  palettes = available;
}
