let
  hexMap = {
    "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4; "5" = 5; "6" = 6; "7" = 7;
    "8" = 8; "9" = 9; "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
    "A" = 10; "B" = 11; "C" = 12; "D" = 13; "E" = 14; "F" = 15;
  };

  # Robust Lookup: Fails with clear error on invalid chars
  toInt = c:
    if builtins.hasAttr c hexMap
    then hexMap.${c}
    else throw "hexToRgb: Invalid hex digit '${c}'";

  requiredKeys = [
    "nord0" "nord1" "nord2" "nord3" "nord4" "nord5" "nord6" "nord7"
    "nord8" "nord9" "nord10" "nord11" "nord12" "nord13" "nord14" "nord15"
  ];
in
rec {
  # 1. Helper: Convert "#RRGGBB" to "R,G,B"
  hexToRgb = hex:
    # Guard Clause: Validiert Format vor weiterer Verarbeitung (deadnix clean)
    if (builtins.stringLength hex != 7 || builtins.substring 0 1 hex != "#")
    then throw "hexToRgb: Invalid hex color '${hex}' (expected #RRGGBB)"
    else
    let
      r = builtins.substring 1 2 hex;
      g = builtins.substring 3 2 hex;
      b = builtins.substring 5 2 hex;

      pairVal = s: (toInt (builtins.substring 0 1 s)) * 16 + (toInt (builtins.substring 1 1 s));
    in
    "${toString (pairVal r)},${toString (pairVal g)},${toString (pairVal b)}";

  # 2. Helper: Validate Palette Schema (Fail Fast)
  # Hardening: Wir nehmen hexToRgb NICHT aus args für die Validierung,
  # sondern nutzen explizit das lokale 'hexToRgb' (via rec oder Scope).
  mkPalette = { name, colors, ... }@args:
    # Type Safety Checks
    if !builtins.isString name then throw "mkPalette: 'name' must be a string"
    else if !builtins.isAttrs colors then throw "mkPalette: 'colors' must be an attrset"
    else
    let
      missing = builtins.filter (k: ! (builtins.hasAttr k colors)) requiredKeys;

      # Hardening: Nutze lokales hexToRgb für den Check.
      # Selbst wenn 'args' eine falsche Funktion enthält, wird hier korrekt geprüft.
      validate = builtins.map (k: hexToRgb colors.${k}) requiredKeys;
    in
    if missing != []
    then throw "Palette '${name}' invalid. Missing keys: ${builtins.concatStringsSep ", " missing}"
    # deepSeq erzwingt die Ausführung von 'validate'
    else builtins.deepSeq validate args;
}
