let
  utils = import ./utils.nix;
  
  p = {
    base = "#191724"; surface = "#1f1d2e"; overlay = "#26233a";
    muted = "#6e6a86"; subtle = "#908caa"; text = "#e0def4";
    love = "#eb6f92"; gold = "#f6c177"; rose = "#ebbcba";
    pine = "#31748f"; foam = "#9ccfd8"; iris = "#c4a7e7";
    highlightLow = "#21202e"; highlightMed = "#403d52"; highlightHigh = "#524f67";
  };
in
utils.mkPalette {
  name = "rose-pine";
  inherit (utils) hexToRgb;

  colors = {
    # Backgrounds
    nord0 = p.base;
    nord1 = p.surface;
    nord2 = p.overlay;
    nord3 = p.muted;

    # Text
    nord4 = p.text;
    nord5 = p.text;
    nord6 = p.text; # Fix: Ensure Bright White is bright

    # Accents
    nord7 = p.foam;    # Cyan
    nord8 = p.foam;    # Cyan
    nord9 = p.pine;    # Blueish Green
    nord10 = p.pine;   # Blueish

    # Functional
    nord11 = p.love;   # Red
    nord12 = p.rose;   # Orange/Pink
    nord13 = p.gold;   # Yellow
    nord14 = p.pine;   # Green
    nord15 = p.iris;   # Magenta
  };
}
