{
  # The Official Nord Palette
  # Source: https://www.nordtheme.com/docs/colors-and-palettes
  colors = {
    # Polar Night (Backgrounds)
    nord0 = "#2E3440"; # Base
    nord1 = "#3B4252"; # Lighter Base (Selection/Panel)
    nord2 = "#434C5E"; # Selection
    nord3 = "#4C566A"; # Comments/Overlay

    # Snow Storm (Text)
    nord4 = "#D8DEE9"; # Main Text
    nord5 = "#E5E9F0"; # Bright Text
    nord6 = "#ECEFF4"; # Brightest Text

    # Frost (Accents - Blue/Teal)
    nord7 = "#8FBCBB"; # Teal
    nord8 = "#88C0D0"; # Cyan
    nord9 = "#81A1C1"; # Blue
    nord10 = "#5E81AC"; # Dark Blue

    # Aurora (Functional - Red/Orange/Yellow/Green/Purple)
    nord11 = "#BF616A"; # Red (Error)
    nord12 = "#D08770"; # Orange (Warning)
    nord13 = "#EBCB8B"; # Yellow (Warning/Notify)
    nord14 = "#A3BE8C"; # Green (Success)
    nord15 = "#B48EAD"; # Purple (Other)
  };

  # Helper: Convert "#RRGGBB" to "R,G,B"
  # This is crucial for KMSCon, Sway, and other low-level configurations 
  # that do not accept standard hex codes.
  hexToRgb = hex: let
    # Helper function to convert 2-digit hex string (e.g., "A3") to decimal (163)
    toInt = str: let
      hexToInt = {
        "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4; "5" = 5; "6" = 6; "7" = 7;
        "8" = 8; "9" = 9; "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
        "A" = 10; "B" = 11; "C" = 12; "D" = 13; "E" = 14; "F" = 15;
      };
      c1 = hexToInt.${builtins.substring 0 1 str};
      c2 = hexToInt.${builtins.substring 1 1 str};
    in c1 * 16 + c2;

    # Extract R, G, B components from the 6-digit hex code
    r = builtins.substring 1 2 hex;
    g = builtins.substring 3 2 hex;
    b = builtins.substring 5 2 hex;
  in "${toString (toInt r)},${toString (toInt g)},${toString (toInt b)}";
}
