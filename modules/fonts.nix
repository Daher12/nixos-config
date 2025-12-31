{ pkgs, ... }:
{
  fonts = {
    # Debloat: Don't install generic X11 fonts
    enableDefaultPackages = false;
    
    # Create a font directory for applications to discover fonts
    fontDir.enable = true;
    
    packages = with pkgs; [
      # Core UI Fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      
      # Symbols (Essential for Waybar/Starship)
      nerd-fonts.symbols-only
      
      # Monospace (Coding)
      nerd-fonts.caskaydia-cove # Your preferred coding font
      fira-code
      
      # Desktop Fonts (Used by Colloid/Nord themes often)
      inter
      roboto
      cantarell-fonts
    ];

    # Expert Tuning: Fontconfig
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Inter" "Noto Sans" ];
        monospace = [ "CaskaydiaCove Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
      # Fix pixelation on low-DPI screens (though Yoga is HiDPI)
      antialias = true;
      hinting = {
        enable = true;
        style = "slight"; # 'slight' usually looks best on modern screens
      };
      subpixel.rgba = "rgb";
    };
  };
}
