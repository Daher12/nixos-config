{ pkgs, palette, ... }:

let
  p = palette.colors;
  toRgb = hex: palette.hexToRgb hex;
in
{
  # --- SILENT BOOT TWEAKS (Restored) ---
  # Prevent standard text login from seizing TTY1, which causes 
  # a visual "glitch" before GDM/GNOME takes over.
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Disable standard TTY artifacts
  console.useXkbConfig = true;

  # --- KMSCON (The "Wimpy" Console) ---
  services.kmscon = {
    enable = true;
    hwRender = true;
    
    # Use the same font as your terminal
    fonts = [{
      name = "CaskaydiaCove Nerd Font";
      package = pkgs.nerd-fonts.caskaydia-cove;
    }];

    extraConfig = ''
      font-size=14
      font-dpi=120
      sb-size=10000
      
      # Nord Theme Injection
      palette=custom
      palette-background=${toRgb p.nord0}
      palette-foreground=${toRgb p.nord4}
      
      # ANSI Colors
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
}
