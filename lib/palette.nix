# Nord Color Palette
# Provides consistent theming across kmscon, terminal, and GTK configurations.
# Source: https://www.nordtheme.com/docs/colors-and-palettes
#
# Usage:
#   - Injected via specialArgs.palette in flake.nix
#   - Access colors: palette.colors.nord0
#   - Convert to RGB: palette.hexToRgb palette.colors.nord0

{
  colors = {
    # Polar Night (Backgrounds)
    nord0 = "#2E3440";
    nord1 = "#3B4252";
    nord2 = "#434C5E";
    nord3 = "#4C566A";

    # Snow Storm (Text)
    nord4 = "#D8DEE9";
    nord5 = "#E5E9F0";
    nord6 = "#ECEFF4";

    # Frost (Accents)
    nord7 = "#8FBCBB";
    nord8 = "#88C0D0";
    nord9 = "#81A1C1";
    nord10 = "#5E81AC";

    # Aurora (Functional)
    nord11 = "#BF616A";
    nord12 = "#D08770";
    nord13 = "#EBCB8B";
    nord14 = "#A3BE8C";
    nord15 = "#B48EAD";
  };

  # Convert "#RRGGBB" to "R,G,B" for kmscon and other tools
  hexToRgb =
    hex:
    let
      toInt =
        str:
        let
          hexToInt = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
          c1 = hexToInt.${builtins.substring 0 1 str};
          c2 = hexToInt.${builtins.substring 1 1 str};
        in
        c1 * 16 + c2;

      r = builtins.substring 1 2 hex;
      g = builtins.substring 3 2 hex;
      b = builtins.substring 5 2 hex;
    in
    "${toString (toInt r)},${toString (toInt g)},${toString (toInt b)}";
}
