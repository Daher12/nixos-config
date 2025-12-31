{ pkgs, lib, ... }:
{
  # --- 1. XSERVER ---
  services.xserver = {
    enable = true;
    xkb.layout = "de";
    excludePackages = [ pkgs.xterm ]; 
  };
  
  # --- 2. DISPLAY MANAGER (GDM - New Path) ---
  services.displayManager.gdm = {
    enable = true;
    wayland = true; 
  };
  
  # --- 2.5. AUTOLOGIN (MOVED UP) ---
  services.displayManager.autoLogin = { 
    enable = true;
    user = "dk";
  };


  # --- 3. DESKTOP MANAGER (GNOME - New Path) ---
   services.desktopManager.gnome = {
     enable = true;
     extraGSettingsOverridePackages = [ pkgs.mutter ];
     extraGSettingsOverrides = ''
       [org.gnome.mutter]
       experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
     '';
   };

  # --- Aggressive Debloat ---
  services.gnome = {
    games.enable = false;  
    core-apps.enable = false;
    tinysparql.enable = lib.mkForce false;
    localsearch.enable = lib.mkForce false;
    evolution-data-server.enable = lib.mkForce false;
    gnome-online-accounts.enable = lib.mkForce false;
    gnome-browser-connector.enable = false;
  };

  # --- Security & Keyring ---
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;

  # --- Clean Up Default Apps ---
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos gnome-tour gedit cheese gnome-music 
    epiphany geary totem gnome-contacts gnome-weather 
    gnome-maps yelp seahorse
    gnome-user-docs
    gnome-calendar
    simple-scan
    gnome-logs
    gnome-connections
  ]);

  # --- Core & Essential Additions ---
  environment.systemPackages = with pkgs; [
    # Core Apps
    nautilus
    file-roller
    
    # Utilities
    gnome-tweaks
    loupe
    wl-clipboard
    gnome-text-editor
    gnome-calculator
    
    # Theme
    gnome-themes-extra
    
    # Extensions (Remaining)
    gnomeExtensions.user-themes       # REQUIRED for Shell Themes
    gnomeExtensions.blur-my-shell     # Aesthetics
  ];

  # --- Hardware & System Integration ---
  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
  programs.dconf.enable = true;
}
